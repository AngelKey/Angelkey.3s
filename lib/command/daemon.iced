
{Base} = require './base'
{add_option_dict} = require './argparse'
log = require '../log'
node_init = require 'init'
{Server} = require '../server'

#=========================================================================

exports.Command = class Command extends Base

  OPTS : 
    d :
      alias : 'debug'
      help : 'stay in foreground for debugging'

  #------------------------------

  add_subcommand_parser : (scp) ->
    opts = 
      help : 'run in daemon mode to coordinate downloads'
    name = 'daemon'
    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    return [ name ]

  #------------------------------

  listen : (cb) ->
    await @config.make_tmpdir defer ok
    if ok
      sn = @config.sockname()
      @server = new Server { sockname : sn }
      await @server.listen defer err
      if err?
        log.error "Error listening on #{sn}: #{err}"
        ok = false
      await setTimeout defer(), 1000
    cb ok

  #------------------------------

  init : (cb) ->
    await super defer ok
    await @listen defer ok if ok
    cb ok

  #------------------------------

  run : (cb) ->
    await @init defer ok
    cb ok

#=========================================================================
