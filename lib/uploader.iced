#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
{awsw} = require './aws'
ProgressBar = require 'progress'
log = require './log'
AWS = require 'aws-sdk'
{AwsBase} = require './aws'
{js2unix} = require './util'

#=========================================================================

exports.Uploader = class Uploader extends AwsBase

  BLOCKSIZE = 1024 * 1024

  #--------------

  constructor : ({@base, @file}) ->
    super { cmd : @base }
    @chunksz = Uploader.BLOCKSIZE
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = null
    @upid = null
    @archive_id = null
    @bar = null
    @archiveSize = 0
    @full_hasher = AWS.util.crypto.createHash 'sha256'

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
    @start_progress() if ok and @interactive()
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
    @bar.tick 1 

  #--------------

  index : (cb) -> 
    # The primary key is the realpath + the modification time, in case
    # we want to store different versions of the file....
    mtime = js2unix @file.stat.mtime.getTime()
    ctime = js2unix @file.stat.ctime.getTime()
    atime = js2unix Date.now()
    attributes =  {
      path : @file.realpath,
      hash : @tree_hash,
      atime, ctime, mtime,
      size : @archiveSize,
      enc : @file.enc.toString()
    }
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

  finish : (cb) ->
    console.log "" if @bar?
    await @finish_upload defer ok
    await @index defer ok if ok
    cb ok

  #--------------

  params : (block) -> 
    start = block.offset
    end = start + block.len()
    @archiveSize = end if end > @archiveSize
    return {
      vaultName : @vault()
      uploadId : @upid
      range : "bytes #{start}-#{end-1}"
      body : block.buf
    }

  #--------------

  write : (block, cb) ->
    chnk = block.buf
    @full_hasher.update chnk
    @leaves.push AWS.util.crypto.sha256 chnk
    await @glacier().uploadMultipartPart params, defer err, data
    @bar.tick block.len() if @bar?
    if err?
      @warn "In upload #{param.range}: #{err}"
    cb err

  #--------------

  finish_upload : (cb) ->
    @tree_hash = @glacier().buildHashTree @leaves
    @full_hash = full_hasher.digest 'hex'

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

