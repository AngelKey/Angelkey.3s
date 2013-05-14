
{Base} = require './base'
{add_option_dict} = require './argparse'
log = require '../log'
{Server} = require '../server'
{daemon} = require '../util'
fs = require 'fs'

#=========================================================================

exports.Command = class Command extends Base

  constructor : (args...) ->
    super args...
    @_e = []

  #------------------------------

  err : (m) ->
    log.error m
    @_e.push m

  #------------------------------

  OPTS : 
    q :
      alias : 'daemon'
      action : 'storeTrue'
      help : 'work in background mode, logging to a file'

  #------------------------------

  add_subcommand_parser : (scp) ->
    opts = 
      help : 'run in daemon mode to coordinate downloads'
    name = 'server'
    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    return [ name ]

  #------------------------------

  listen : (cb) ->
    await @config.make_tmpdir defer ok
    if ok
      sf = @config.sockfile()
      @server = new Server { @config }
      await @server.listen defer err
      if err?
        @err "Error listening on #{sf}: #{err}"
        ok = false
    cb ok

  #------------------------------

  daemonize : (cb) ->
    log.info "B1"
    ok = true
    await fs.writeFile @config.pidfile(), "#{process.pid}", defer err
    log.info "B2"
    if err? 
      ok = false
      @err "Error in making pidfile: #{err}"
    log.info "B3"
    if ok
      log.info @config.logfile()
      log.daemonize @config.logfile()
    log.info "B4"
    cb ok

  #------------------------------

  init : (cb) ->
    log.info "A1"
    await super defer ok
    log.info "A2"
    await @listen defer ok if ok
    log.info "A3"
    if @argv.daemon and ok
      await @daemonize defer ok
    cb ok

  #------------------------------

  run : (cb) ->
    await @init defer ok
    process.send { ok, err : @_e  }
    await @server.run defer()
    cb ok

#=========================================================================
