#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
log = require './log'
{Base} = require './awsio'
util = require 'util'


#=========================================================================

class MetaData
  constructor : ({@glacier_id, @mtime, @ctime, @atime, @hash, @path, @enc}) -> 

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

  initiate_job : (cb) -> 
    arg = null
    cb true

  #--------------

  wait_for_job : (cb) -> cb true
  download_file : (cb) -> cb true
  finalize_file : (cb) -> cb true

  #--------------

  find_file : (cb) ->
    sel = "select * from `#{@vault()}` where path = '#{@filename}'"
    arg =
      SelectExpression : sel
      ConsistentRead : false
    await @sdb().select arg, defer err, data
    ok = true
    @md = null
    if err?
      @warn "simpledb.select #{JSON.stringify arg}: #{err}"
      ok = false
    else if not data?.Items?.length
      @warn "file not found"
      ok = false
    else
      for i in data.Items
        d = { glacier_id : i.Name }
        for {Name,Value} in i.Attributes
          if Name in [ "ctime", "mtime", "atime", "enc" ]
            Value = parseInt Value, 10
          d[Name] = Value
        if not @md? or @md.ctime < d.ctime
          @md = new MetaData d
      if (n = data.Items.length) > 1
        log.info "Found #{n} items for '#{@filename}'; taking newest"

    cb ok

  #--------------

  warn : (msg) ->
    log.warn "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}"

  #--------------

#=========================================================================

