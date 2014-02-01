#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv
ProgressBar = require 'progress'

warn = (x) -> console.log x

load_config = (cb) ->
  config = path.join process.env.HOME, ".mkb.conf"
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
dynamo = new AWS.DynamoDB({apiVersion : '2012-08-10'})

#=========================================================================

class File

  #--------------

  constructor : (@glacier, @dynamo, @vault, @filename) ->
    @chunksz = 1024 * 1024
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = null
    @upload_id = null
    @archive_id = null
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

    await fs.stat @filename, defer @err, @stat

    if @err?
      @warn "stat"
      ok = false
    else if not @stat.isFile()
      @warn "not a file!"
      ok = false
    else
      @filesz = @stat.size

    if ok
      await fs.realpath @filename, defer @err, @realpath
      if @err?
        @warn "realpath"
        ok = false

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
    warn "In #{@filename}#{if @upload_id? then ('/'+@upload_id) else ''}: #{msg}: #{@err}"

  #--------------

  init : (cb) ->
    params =
      vaultName : @vault
      partSize : @chunksz.toString()
    await @glacier.initiateMultipartUpload params, defer @err, @multipart
    @upload_id = @multipart.uploadId if @multipart?
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

  index : (cb) -> 
    arg = 
      TableName : @vault
      Item : 
        path : S : @realpath 
        hash : S : @tree_hash
        ctime : N : "#{Math.floor @stat.ctime.getTime()}"
        mtime : N : "#{Math.floor @stat.mtime.getTime()}"
        atime : N : "#{Date.now()}"
        glacier_id : S : @archive_id
    await @dynamo.putItem arg, defer err
    if err?
      @warn "dynamo.putItem #{JSON.stringify arg}"
      ok = false
    else
      ok = true
    cb ok

  #--------------

  run : (cb) ->
    await @open defer ok
    @start_progress() if ok
    await @upload defer ok if ok
    await @index defer ok if ok
    await fs.close @fd, defer() if @fd
    cb ok

  #--------------

  body : (cb) ->
    full_hash = AWS.util.crypto.createHash 'sha256'
    @leaves = []

    params = 
      vaultName : @vault
      uploadId : @upload_id

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
    @full_hash = full_hash.digest 'hex'

    cb not @err

  #--------------

  finish : (cb) ->
    @tree_hash = @glacier.buildHashTree @leaves

    params = 
      vaultName : @vault
      uploadId : @upload_id
      archiveSize : "#{@pos}"
      checksum : @tree_hash

    await @glacier.completeMultipartUpload params, defer @err, data
    if data?
      @archive_id = @data.archiveId

    cb not @err

#=========================================================================

file = new File glacier, dynamo, argv.v, argv._[0]
await file.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

