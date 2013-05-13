#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
{awsw} = require './aws'
ProgressBar = require 'progress'
log = require './log'
AWS = require 'aws-sdk'
{Batcher} = require './batcher'
{Base} = require './awsio'

#=========================================================================

exports.Uploader = class Uploader extends Base

  #--------------

  constructor : ({@base, @file}) ->
    super { @base }
    @chunksz = 1024 * 1024
    @batcher = new Batcher @file.stream, @chunksz 
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = null
    @upid = null
    @archive_id = null
    @bar = null

  #--------------

  warn : (msg) ->
    log.warn "In #{@file.filename}#{if @upid? then ('/'+@upid) else ''}: #{msg}"

  #--------------

  init : (cb) ->
    params =
      vaultName : @vault()
      partSize : @chunksz.toString()
    await @glacier().initiateMultipartUpload params, defer err, @multipart
    @upid = @multipart.uploadId if @multipart?
    if err?
      @warn "intiate error: #{err}"
      ok = false
    else ok = true
    cb ok

  #--------------

  upload : (cb) ->
    ok = true
    await @body defer ok if ok
    await @finish defer ok if ok
    cb ok

  #--------------

  start_progress : () ->
    msg = " uploading [:bar] :percent <:elapseds|:etas> #{@file.filename} (:current/:totalb)"
    opts =
      complete : "="
      incomplete : " "
      width : 25
      total : @file.stat.size
    @bar = new ProgressBar msg, opts

  #--------------

  index : (cb) -> 
    # The primary key is the realpath + the modification time, in case
    # we want to store different versions of the file....
    mtime = Math.floor @file.stat.mtime.getTime()
    ctime = Math.floor @file.stat.ctime.getTime()
    attributes = 
      path : @file.realpath
      hash : @tree_hash
      atime : Date.now()
      ctime : ctime
      mtime : mtime
      enc : @file.enc.toString()
    obj_to_list = (d) -> { Name : k, Value : "#{v}", Replace : true } for k,v of d
    arg = 
      DomainName : @vault()
      ItemName : @archive_id
      Attributes : obj_to_list attributes
    await @sdb().putAttributes arg, defer err
    if err?
      @warn "sdb.putAttributes #{JSON.stringify arg}: #{err}"
      ok = false
    else
      ok = true
    cb ok

  #--------------

  run : (cb) ->
    ok = true
    await @init defer ok if ok
    @start_progress() if ok and @interactive()
    await @upload defer ok if ok
    await @index defer ok if ok
    cb ok

  #--------------

  body : (cb) ->
    full_hash = AWS.util.crypto.createHash 'sha256'
    @leaves = []
    start = 0
    end = 0
    go = true
    ret = true
    await process.nextTick defer()

    params = 
      vaultName : @vault()
      uploadId : @upid

    @bar.tick 1 if @bar?

    while go

      await @batcher.read defer err, eof, chnk
      if err?
        log.error "Error in upload: #{err}"
        go = false
        ret = false
      else if eof
        go = false
      else
        end = start + chnk.length
        full_hash.update chnk
        @leaves.push AWS.util.crypto.sha256 chnk
        params.range = "bytes #{start}-#{end-1}/*"
        params.body = chnk
        await @glacier().uploadMultipartPart params, defer err, data
        @bar.tick chnk.length if @bar?
        if err?
          @warn "In upload #{start}-#{end}: #{err}"
          go = false
        start = end
    console.log ""

    @full_hash = full_hash.digest 'hex'
    @archiveSize = end

    cb ret

  #--------------

  finish : (cb) ->
    @tree_hash = @glacier().buildHashTree @leaves

    params = 
      vaultName : @vault()
      uploadId : @upid
      archiveSize : @archiveSize.toString()
      checksum : @tree_hash

    await @glacier().completeMultipartUpload params, defer err, data

    if err?
      @warn "In complete: #{err}"
      ok = false
    else 
      @archive_id = data.archiveId
      ok = true

    cb ok

#=========================================================================

