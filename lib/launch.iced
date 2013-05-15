
log = require './log'
{daemon} = require './util'
fs = require 'fs'
{client,init_client} = require './client'
{status} = require './constants'

#=========================================================================

exports.Launcher = class Launcher 

  constructor : ({@config}) ->

  #------------------------------

  run : (cb) ->
    ok = true
    await @check_socket defer rc
    if rc is status.E_INVAL
      ok = false
    else if rc is status.E_NOT_FOUND
      await @launch defer ok
    if ok
      log.debug "+> connecting to client"
      await init_client @config.sockfile(), defer ok
      log.debug "-> connected w/ status=#{ok}"
      if not ok
        log.error "Failed to initialize client"
    if ok
      await client().ping defer ok
      if not ok
        log.error "Failed to ping daemon process"
      else
        log.info "successfully pinged daemon process"
    cb ok

  #------------------------------

  check_socket : (cb) ->
    f = @config.sockfile()
    await fs.stat f, defer err, stat

    rc = if err? then status.E_NOT_FOUND
    else if not stat.isSocket()
      log.error "#{f}: socket wasn't a socket"
      status.E_INVAL
    else status.OK

    cb rc

  #------------------------------

  launch : (cb) ->
    log.info "+> Launching background server"
    ch = daemon [ "server", "--daemon" ]
    await ch.once 'message', defer msg
    if msg.err?.length
      for m in msg.err
        log.error "Error launching daemon: #{m}"
    else
      log.info "-> Launch succeded: ok=#{msg.ok}"
    cb msg.ok

#=========================================================================
