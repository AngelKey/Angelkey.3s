
rpc = require 'framed-msgpack-rpc'
fs = require 'fs'
{ExitHandler} = require './exit'
{constants} = require './constants'

#=========================================================================

exports.Server = class Server extends rpc.SimpleServer

  constructor : ({@sockname}) ->
    super { path : @sockname }

  get_program_name : () -> constants.PROT

  listen : (cb) ->
    await super defer err
    @eh = new ExitHandler { @sockname} unless err?
    cb err

#=========================================================================
