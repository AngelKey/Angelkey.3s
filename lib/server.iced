
rpc = require 'framed-msgpack-rpc'
fs = require 'fs'
{ExitHandler} = require './exit'
{status,constants} = require './constants'
log = require './log'

#=========================================================================

exports.Server = class Server extends rpc.SimpleServer

  constructor : ({@base}) ->
    super { path : @base.config.sockfile() }

  get_program_name : () -> constants.PROT

  listen : (cb) ->
    await super defer err
    @eh = new ExitHandler { config : @base.config } unless err?
    cb err

  h_ping : (arg, res) -> res.result { rc : status.OK }

  h_download : (arg, res) ->
    console.log "got download #{JSON.stringify arg}"
    res.result { rc: status.OK }

  run : (cb) ->
    @eh.call_on_exit cb

#=========================================================================
