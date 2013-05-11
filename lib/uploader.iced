#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
{awsw} = require './aws'
ProgressBar = require 'progress'
log = require './log'
AWS = require 'aws-sdk'
{Batcher} = require './batcher'

#=========================================================================

exports.Uploader = class Uploader

  #--------------

  constructor : ({@base, @file, @interactive}) ->
    @chunksz = 1024 * 1024
    @batcher = new Batcher @file.stream, @chunksz 
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = null
    @id = null
    @bar = null

  #--------------

  glacier : -> @base.aws.glacier
  dynamo  : -> @base.aws.dynamo
  vault   : -> @base.config.vault()

  #--------------

  warn : (msg) ->
    log.warn "In #{@file.filename}#{if @id? then ('/'+@id) else ''}: #{msg}"

  #--------------

  init : (cb) ->
    params =
      vaultName : @vault()
      partSize : @chunksz.toString()
    await @glacier().initiateMultipartUpload params, defer err, @multipart
    @id = @multipart.uploadId if @multipart?
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
    arg = 
      TableName : @vault()
      Item : 
        path : S : @file.realpath 
        hash : S : @tree_hash
        ctime : N : "#{Math.floor @file.stat.ctime.getTime()}"
        mtime : N : "#{Math.floor @file.stat.mtime.getTime()}"
        atime : N : "#{Date.now()}"
        glacier_id : S : @id
        enc : N : @file.enc.toString()
    await @dynamo().putItem arg, defer err
    if err?
      @warn "dynamo.putItem #{JSON.stringify arg}: #{err}"
      ok = false
    else
      ok = true
    cb ok

  #--------------

  run : (cb) ->
    ok = true
    await @init defer ok if ok
    @start_progress() if ok and @interactive
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
      uploadId : @id

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
      uploadId : @id
      archiveSize : @archiveSize.toString()
      checksum : @tree_hash

    await @glacier().completeMultipartUpload params, defer err, data

    if err?
      @warn "In complete: #{err}"
      ok = false
    else ok = true

    cb ok

#=========================================================================

