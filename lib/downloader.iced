#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
log = require './log'
{Base} = require './awsio'
util = require 'util'


#=========================================================================

class MetaData
  constructor : ({@glacier_id, @mtime, @ctime, @atime, @hash, @path, @enc,
       @jid}) -> 
    @jid = null if @jid?.length is 0

#=========================================================================

class Status
  @NONE = 0
  @IN_PROGRESS = 1
  @SUCCEEDED = 2
  @FAILED = 3
  @EXPIRED = 4
  @ERROR = 5

  @LOOKUP = 
    InProgress : @IN_PROGRESS
    Succeeded : @SUCCEEDED
    Failed : @FAILED
    Expired : @EXPIRED

  @from_string : (s) -> Status.LOOKUP[s] or Status.ERROR

  @is_dead : (s) -> 
    s in [ Status.NONE, Status.FAILED, Status.EXPIRED, Status.ERROR ]


#=========================================================================

class Job 

  constructor : ({@id, @status, @completed, @started}) ->
    # Reasonable defaults
    @status = Status.NONE unless @status?
    @started = Date.now() unless @started?

    # Any job that completed more than 20hrs ago, let's consider
    # expired
    if @status is Status.SUCEEDED and (Date.now() - @completed) > 60*60*20
      @status = Status.EXPIRED

  is_dead : () -> Status.is_dead @status
  is_pending : () -> @status is Status.IN_PROGRESS
  is_success : () -> @status is Status.SUCCEEDED

#=========================================================================

exports.Downloader = class Downloader extends Base

  #--------------

  constructor : ({@base, @filename}) ->
    super { @base }
    @chunksz = 1024 * 1024
    @job = null

  #--------------

  run : (cb) ->
    ok = true
    await @find_file defer ok     if ok
    await @lookup_job defer()     if ok

    if ok and (not @job? or @job.is_dead())
      console.log "shit, wound up in IJ"
      process.exit -3
      await @initiate_job defer ok if ok

    if ok and @job and @job.is_pending()
      await @wait_for_job defer ok if ok

    if ok and @job and @job.is_success()
      await @download_file defer ok if ok 
      await @finalize_file defer ok if ok
    cb ok 

  #--------------

  lookup_job : (cb) ->
    status = Status.NONE
    if @md.jid? and not @job?
      arg = 
        vaultName : @vault()
        jobId : @md.jid
      await @glacier().describeJob arg, defer err, res
      log.info "Found job desc: #{JSON.stringify res}" if res?
      ok = true
      if err?
        status = Status.ERROR
        warn "Error in polling job: #{err}"
      else if (t = res.Action) isnt 'ArchiveRetrieval'
        status = Status.ERROR
        warn "Wrong job type: #{t}"
      else
        params = 
          id : @md.jid
          status : Status.from_string res.StatusCode
        params.started = Date.parse d if (d = res.CreationDate)?
        params.completed = Date.parse d if (d = res.CompletionDate)?
        @job = new Job params

    @job = new Job { status } unless @job?

    if @md.jid? and @job.is_dead()
      await @write_job_id null, defer ok

    cb @job

  #--------------

  write_job_id : (jid, cb) ->
    arg =
      DomainName : @vault()
      ItemName : @md.glacier_id
      Attributes : [{
        Name : "jid"
        Value : (jid or "")
        Replace : true
      }]
    await @sdb().putAttributes arg, defer err
    ok = true
    if err?
      ok = false
      @warn "Failed to write_job_id to sdb: #{err}"
    cb ok

  #--------------

  initiate_job : (cb) -> 
    arg = 
      vaultName : @vault()
      jobParameters :
        Type : "archive-retrieval"
        ArchiveId : @md.glacier_id
        Description : "mkb down #{@filename}"
        SNSTopic : @base.config.arns().sns
    await @glacier().initiateJob arg, defer err, res
    ok = true
    if err?
      @warn "Initiate retrieval job failed: #{err}"
      ok = false
    else
      log.info "InitiateJob gave #{JSON.stringify res}"
      @job = new Job { status : Status.InProgress, id : res.jobId }
    if ok
      await @write_job_id @job.id, defer ok
    cb ok

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

        if not @md? or (@md.ctime < d.ctime) or 
              (@md.ctime is d.ctime and @md.atime < d.atime)
          @md = new MetaData d

      if (n = data.Items.length) > 1
        log.info "Found #{n} items for '#{@filename}'; taking newest"

      log.info "Found metadata #{JSON.stringify @md}" if @md

    cb ok

  #--------------

  warn : (msg) ->
    log.warn "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}"

  #--------------

#=========================================================================

