
rpc = require 'framed-msgpack-rpc'
fs = require 'fs'
{ExitHandler} = require './exit'
{constants} = require './constants'

#=========================================================================

exports.Server = class Server extends rpc.SimpleServer

  constructor : ({@config}) ->
    super { path : @config.sockfile() }

  get_program_name : () -> constants.PROT

  listen : (cb) ->
    await super defer err
    @eh = new ExitHandler { @config } unless err?
    cb err

  run : (cb) ->
    @eh.call_on_exit cb

#=========================================================================
