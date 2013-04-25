#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv
ProgressBar = require 'progress'

warn = (x) -> console.log x

load_config = (cb) ->
  config = path.join process.env.HOME, ".mkbkp.conf"
  await fs.exists config, defer ok
  if ok
    await fs.readFile config, defer err, file
    if err?
      warn "Failed to load file #{config}: #{err}"
      ok = false
  if ok
    try
      json = JSON.parse file
    catch e
      warn "Invalid json in #{file}: #{e}"
      ok = false
  if ok
    AWS.config.update json
  else
    warn "Failed to load config..."
  cb()

await load_config defer()
glacier = new AWS.Glacier()

#=========================================================================

class File

  #--------------

  constructor : (@glacier, @vault, @filename) ->
    @chunksz = 1024 * 1024
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = null
    @id = null
    @bar = null

  #--------------

  can_read : -> (not @eof) and (not @err)

  #--------------

  read_chunk : (cb) ->
    i = 0

    start = @pos

    while @can_read() and i < @chunksz
      left = @chunksz - i
      await fs.read @fd, @buf, i, left, @pos, defer @err, nbytes, buf
      if @err?
        @warn "reading @#{@pos}"
      else if nbytes is 0
        @eof = true
      else
        i += nbytes
        @pos += nbytes
    end = @pos

    ret = if i < @chunksz then @buf[0...i]
    else if @err then null
    else @buf

    cb ret, start, end

  #--------------

  open : (cb) ->
    ok = true

    await fs.stat @filename, defer @err, stat

    if @err?
      @warn "stat"
      ok = false
    else if not stat.isFile()
      @warn "not a file!"
      ok = false
    else
      @filesz = stat.size

    if ok
      await fs.open @filename, "r", defer @err, @fd
      if @err?
        @warn "open"
        ok = false
      else
        @pos = 0
        @eof = false
    cb ok

  #--------------

  warn : (msg) ->
    warn "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}: #{@err}"

  #--------------

  init : (cb) ->
    params =
      vaultName : @vault
      partSize : @chunksz.toString()
    await @glacier.initiateMultipartUpload params, defer @err, @multipart
    @id = @multipart.uploadId if @multipart?
    warn "New upload id: #{@id}"
    cb not @err

  #--------------

  upload : (cb) ->
    await @init defer ok
    await @body defer ok if ok
    await @finish defer ok if ok
    cb ok

  #--------------

  start_progress : () ->
    msg = " uploading [:bar] :percent <:elapseds|:etas> #{@filename} (:current/:totalb)"
    opts =
      complete : "="
      incomplete : " "
      width : 25
      total : @filesz
    @bar = new ProgressBar msg, opts

  #--------------

  run : (cb) ->
    await @open defer ok
    @start_progress() if ok
    await @upload defer ok if ok
    await fs.close @fd, defer() if @fd
    cb ok

  #--------------

  body : (cb) ->
    full_hash = AWS.util.crypto.createHash 'sha256'
    @leaves = []

    params = 
      vaultName : @vault
      uploadId : @id

    while @can_read()
      await @read_chunk defer chnk, start, end

      if chnk?
        full_hash.update chnk
        @leaves.push AWS.util.crypto.sha256 chnk
        params.range = "bytes #{start}-#{end-1}/*"
        params.body = chnk
        await @glacier.uploadMultipartPart params, defer @err, data
        @bar.tick chnk.length

        @warn "upload #{start}-#{end}" if @err?
    console.log ""

    cb not @err

  #--------------

  finish : (cb) ->

    params = 
      vaultName : @vault
      uploadId : @id
      archiveSize : "#{@pos}"
      checksum : @glacier.buildHashTree @leaves

    await @glacier.completeMultipartUpload params, defer @err, data

    cb not @err

#=========================================================================

file = new File glacier, argv.v, argv._[0]
await file.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

