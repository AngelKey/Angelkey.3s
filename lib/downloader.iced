#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
log = require './log'
util = require 'util'
{status} = require './constants'
{Base} = require './awsio'
mycrypto = require './crypto'
stream = require 'stream'
AWS = require 'aws-sdk'
{Tee} = require './tee'
{PasswordManager} = require './pw'

#=========================================================================

class MetaData
  constructor : ({@glacier_id, @mtime, @ctime, @atime, @hash, @path, @enc,
       @jid}) -> 
    @jid = null if @jid?.length is 0

#=========================================================================

exports.JobStatus = class Status
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
  is_ready  : () -> @status is Status.SUCCEEDED

#=========================================================================

class Stream extends stream.Readable

  constructor : ({@dl}) ->
    @i = 0

  _eof : () -> @i >= @dl.md.size

  _read : (sz) ->
    start = @i
    arg = 
      vaultName : @dl.vault()
      jobId : @dl.job.id
      range : "#{start}-#{end-1}"
    end = start + @dl.chunksz
    if end > @dl.md.size then end = @dl.md.size
    @i = end
    await @dl.glacier().getJobOutput arg, defer err, res
    if err?
      log.error "Error in download: #{err}"
      @emit 'error', err
    else
      dat = new Buffer res.body, 'binary'
      h = crypto.createHash('sha256').update(dat).digest('hex')
      if h isnt res.checksum
        log.error "Checksum failure for block #{JSON.stringify arg}"
        @emit 'error', "checksum failure"
      else
        @push dat
        @emit 'end' if @_eof()

#=========================================================================

exports.Downloader = class Downloader extends Base

  #--------------

  constructor : ({@base, @filename, @opts, @km, @md}) ->
    super { @base }
    @chunksz = 1024 * 1024
    @job = null

  #--------------

  toString : () -> "#{@filename} | #{JSON.stringify @md} | #{JSON.stringify @job}"

  #--------------

  is_ready : () -> @job?.is_ready()

  #--------------

  export_to_obj : () -> {
      md : @md
      km : @km
      opts : @opts
  }

  #--------------

  # don't export the key material to AWS
  export_to_desc : () -> {
      md : @md
      opts : @opts
    }

  #--------------

  @import_from_obj :({base, md, km, opts}) ->
    md = new MetaData md
    filename = md.path
    new Downloader { base, filename, md, km, opts }

  #--------------

  launch : (cb) ->
    ok = true
    await @lookup_job defer()     if ok

    if ok and (not @job? or @job.is_dead())
      await @initiate_job defer ok if ok

    cb ok

  #--------------

  output_filename_base : () -> opts.output_path or @filename

  #--------------

  run : (cb) -> 
    input = new Stream { dl : @ }
    unless @opts.no_decrypt
      eng = new mycrypto.Decryptor { pwmgr: @base.pwmgr, stat: @md }
      await eng.init defer ok
      if not ok
        log.error "Could not set up decryption"
    if ok
      ofb = @output_filename_base()
      tmps = []
      if @opts.no_decrypt or @opts.encypted_output
        target = [ofb, @base.config.file_extension() ].join '.'
        tmp_raw = new myfs.Tmp { target }
        tmps.push tmp_raw

      unless @opts.no_decrypt
        tmp = new myfs.Tmp { target : ofb }
        tmps.push tmp

      for t in tmps when ok
        await t.open defer ok

    if ok
      p = input
      if @opts.no_decrypt
        p = p.pipe tmp_raw.stream
      else 
        if @opts.encrypted_output
          p = p.pipe( new Tee { out : tmp_raw.stream } )
        p.pipe(eng).pipe(tmp.stream)

      await input.stream.once 'end', defer()
      await tmp_raw.stream.once 'finish', defer() if tmp_raw?
      await tmp.stream.once 'finish', defer() if tmp?

      for t in tmps
        await @t.finish defer ok

    cb ok 

  #--------------

  lookup_job : (cb) ->
    status = Status.NONE
    if @md.jid? and not @job?
      log.info "+> lookup_job #{@md.jid}"
      arg = 
        vaultName : @vault()
        jobId : @md.jid
      await @glacier().describeJob arg, defer err, res
      log.info "Found job desc: #{JSON.stringify res}" if res?
      ok = true
      if err?
        status = Status.ERROR
        @warn "Error in polling job: #{err}"
      else if (t = res.Action) isnt 'ArchiveRetrieval'
        status = Status.ERROR
        @warn "Wrong job type: #{t}"
      else
        params = 
          id : @md.jid
          status : Status.from_string res.StatusCode
        params.started = Date.parse d if (d = res.CreationDate)?
        params.completed = Date.parse d if (d = res.CompletionDate)?
        @job = new Job params

      log.info "-> lookup_job #{@md.jid} -> #{status}"

    @job = new Job { status } unless @job?

    if @md.jid? and @job.is_dead()
      log.info "|> clearing out dead job #{@md.jid}"
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
      log.info "|> InitiateJob gave #{JSON.stringify res}"
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
    rc = status.OK
    @md = null
    if err?
      @warn "simpledb.select #{JSON.stringify arg}: #{err}"
      rc = status.E_QUERY
    else if not data?.Items?.length
      @warn "file not found"
      rc = status.E_NOT_FOUND
    else
      for i in data.Items
        d = { glacier_id : i.Name }
        for {Name,Value} in i.Attributes
          if Name in [ "ctime", "mtime", "atime", "enc", "size" ]
            Value = parseInt Value, 10
          d[Name] = Value

        if not @md? or (@md.ctime < d.ctime) or 
              (@md.ctime is d.ctime and @md.atime < d.atime)
          @md = new MetaData d

      if (n = data.Items.length) > 1
        log.info "Found #{n} items for '#{@filename}'; taking newest"

      log.info "Found metadata #{JSON.stringify @md}" if @md

    cb rc, @md

  #--------------

  send_download_to_daemon : (cli, cb) ->
    arg = @export_to_obj()
    await cli.send_download arg, defer ok
    cb ok

  #--------------

  get_key_material : (cb) ->
    await mycrypto.derive_key_material @pwmgr(), false, defer @km
    cb @km?

  #--------------

  warn : (msg) ->
    log.warn "In #{@filename}#{if @id? then ('/'+@id) else ''}: #{msg}"

  #--------------

#=========================================================================

