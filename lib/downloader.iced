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

exports.Downloader = class Downloader extends Base

  #--------------

  constructor : ({@base, @filename}) ->
    super { @base }
    @chunksz = 1024 * 1024

  #--------------

  run : (cb) ->
    ok = true
    await @find_file defer ok     if ok
    await @initiate_job defer ok  if ok
    await @wait_for_job defer ok  if ok
    await @download_file defer ok if ok 
    await @finalize_file defer ok if ok
    cb ok 

  #--------------

  initiate_job : (cb) -> cb true
  wait_for_job : (cb) -> cb true
  download_file : (cb) -> cb true
  finalize_file : (cb) -> cb true

  #--------------

  find_file : (cb) ->
    arg =
      TableName : @vault()
      Key : path : S : @filename
      AttributesToGet : [ "hash", "glacier_id", "atime", "ctime", "mtime", "enc" ]

    await @dynamo().getItem arg, defer err, res
    ok = true
    if err?
      @warn "dynamo.getItem #{JSON.stringify arg}: #{err}"
      ok = false
    else
      console.log res
    cb ok
  #--------------

  warn : (msg) ->
    log.warn "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}"

  #--------------

#=========================================================================

