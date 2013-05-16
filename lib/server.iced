
rpc = require 'framed-msgpack-rpc'
fs = require 'fs'
{ExitHandler} = require './exit'
{status,constants} = require './constants'
log = require './log'
{Downloader} = require './downloader'

#=========================================================================

exports.Server = class Server extends rpc.SimpleServer

  constructor : ({@base}) ->
    super { path : @base.config.sockfile() }
    @launcher = new Launcher { @base, server : @ }

  get_program_name : () -> constants.PROT

  listen : (cb) ->
    await super defer err
    unless err?
      @eh = new ExitHandler { config : @base.config } 
      @launcher.start()
    cb err

  h_ping : (arg, res) -> res.result { rc : status.OK }

  h_download : (arg, res) ->
    await @launcher.incoming_job arg, defer rc
    res.result { rc }

  run : (cb) ->
    @eh.call_on_exit cb

#=========================================================================

class Queue 

  constructor : ({@launcher, @lim}) ->
    @n = 0
    @_q = []

  enqueue : (obj) ->
    if @n < @lim then @_launch_one obj
    else 
      log.info "|> Queueing job, since #{@n}>=#{@lim} outstanding: #{obj.toString()}"
      @_q.push obj

  _lauch_one : (obj, out) ->
    @n++
    await obj.run defer()
    @launcher.completed obj
    @n--
    @done()

  _done : () ->
    room = @lim - @n
    if room and @_q.length
      objs = @_q[0...room]
      @_q = @_q[room...]
      for o in objs
        @_launch_one o

#=========================================================================

class JobLauncher

  #-------------

  constructor : ({@base, @server}) ->
    @jobs = {}
    @q = new Queue { lim : 3, launcher : @ }

  #-------------

  polling_loop : () ->
    loop
      await @poll defer()
      iv = constants.poll_interval[if @jobs.length then "active" else "passive"]
      await setTimeout defer(), iv*1000 

  #-------------

  poll : (cb) ->

  #-------------

  start : () ->
    polling_loop()

  #-------------

  incoming_job : (arg, cb) ->
    filename = arg.md.path
    if (job = @jobs[filename])?
      rc = status.E_DUPLICATE
      log.info "|> skipping duplicated job: #{filename}"
    else
      rc = status.OK
      arg.base = @base
      dl = Downloader.import_from_obj arg
      @jobs[filename] = dl
      log.info "|> incoming job: #{dl.toString()}"

    cb rc

    if dl?
      await dl.launch defer ok

    if not ok
      log.warn "job kickoff failed for #{dl.toString()}"
    else if dl.is_ready()
      @start_download dl

  #-------------

  start_download : (dl) ->
    @q.enqueue dl

  #-------------

#=========================================================================
