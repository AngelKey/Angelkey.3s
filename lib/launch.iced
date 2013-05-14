
log = require './log'
{daemon} = require './util'
fs = require 'fs'
{make_client,check_res} = require './client'

#=========================================================================

exports.Launcher = class Launcher 

  constructor : ({@config}) ->

  #------------------------------

  ping : (cb) ->
    await make_client defer c
    if c?
      await c.invoke "ping", {}, null, defer err, res
      ok = check_res, "ping", err, res
      if err?
        log.error "Error in ping: #{err}"
      else if res.rc isnt 

  #------------------------------

  check_socket : (cb) ->
    f = @config.sockfile()
    await fs.stat f, defer err, stat
    ok = false
    if err?
      log.error "Error statting socket: #{err}"
    else if not stat.isSocket()
      log.error "#{f}: socket wasn't a socket"
    else
      ok = true
    cb ok

  #------------------------------

  launch : (cb) ->
    log.info "+> Launching background server"
    ch = daemon [ "server", "--daemon" ]
    await ch.once 'message', defer msg
    for m in msg.err?
      log.error "Error launching daemon: #{m}"
    else
      log.info "-> Launch succeded: ok=#{msg.ok}"
    cb msg.ok


#=========================================================================
