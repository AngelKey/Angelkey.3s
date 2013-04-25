#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv

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
    console.log json
    AWS.config.update json
  console.log "done---> #{ok}"
  cb()

await load_config defer()
console.log "after load_config"
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
      else if buf is null
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
    console.log "fs open #{@filename}"
    await fs.open @filename, "r", defer @err, @fd
    console.log "open -> #{@fd}"
    if @err?
      @warn "open"
      ok = false
    else
      @pos = 0
      @eof = false
      ok = true
    cb ok

  #--------------

  warn : (msg) ->
    console.log "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}: #{@err}"

  #--------------

  init : (cb) ->
    console.log "in init!"
    params =
      vaultName : @vault
      partSize : @chunksz.toString()
    await @glacier.initiateMultipartUpload params, defer @err, @multipart
    console.log "back from init #{@err}"
    console.log @multipart
    @id = @multipart.uploadId if @multipart?
    cb not @err

  #--------------

  upload : (cb) ->
    console.log "upload"
    await @init defer ok
    await @body defer ok if ok
    await @finish defer ok if ok
    console.log "done with all that -> #{ok}"
    cb ok

  #--------------

  run : (cb) ->
    console.log "in run.."
    await @open defer ok
    console.log "after open #{ok}"
    await @upload defer ok if ok
    console.log "after upload #{ok}"
    await fs.close @fd, defer() if @fd
    cb ok

  #--------------

  body : (cb) ->
    console.log "the body! #{@err}"
    full_hash = AWS.util.crypto.createHash 'sha256'
    @leaves = []

    params = 
      vaultName : @vault
      uploadId : @id

    while @can_read()
      console.log "reading.."
      await @read_chunk defer chnk, start, end
      console.log "read it #{chnk.length}"

      if chnk?
        full_hash.update chnk
        @leaves.push AWS.util.crypto.sha256 chnk
        params.range = "bytes #{start}-#{end-1}/*"
        params.body = chnk
        await @glacier.uploadMultipartPart params, defer @err, data

        @warn "upload #{start}-#{end}" if @err?

    console.log "body is done -> #{@err}"
    cb not @err

  #--------------

  finish : (cb) ->

    params = 
      vaultName : @vault
      uploadId : @id
      archiveSize : @pos
      checksum : @glacier.buildHashTree leaves

    await @glacier.completeMultipartUpdate params, defer @err, data

    cb not @err

#=========================================================================

file = new File glacier, argv.v, argv._[0]
await file.run defer ok

#=========================================================================

