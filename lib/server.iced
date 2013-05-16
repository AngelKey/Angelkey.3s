
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
    @runner = new Runner { @base, server : @ }

  get_program_name : () -> constants.PROT

  listen : (cb) ->
    await super defer err
    unless err?
      @eh = new ExitHandler { config : @base.config } 
      @runner.start()
    cb err

  h_ping : (arg, res) -> res.result { rc : status.OK }

  h_download : (arg, res) ->
    await @runner.incoming_job arg, defer rc
    res.result { rc }

  run : (cb) ->
    @eh.call_on_exit cb

#=========================================================================

class Runner 

  constructor : ({@base, @server}) ->
    @jobs = {}

  start : () ->

  incoming_job : (arg, cb) ->
    filename = arg.md.path
    if (job = @jobs[filename])?
      rc = status.E_DUPLICATE
      log.info "|> skipping duplicated job: #{filename}"
    else
      rc = status.OK
      dl = Downloader.import_from_obj arg
      @jobs[filename] = dl
      log.info "|> incoming job: #{dl.toString()}"
    cb rc

#=========================================================================
