
{Base} = require './base'
{add_option_dict} = require './argparse'
log = require '../log'
{Server} = require '../server'
{daemon} = require '../util'
fs = require 'fs'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  add_subcommand_parser : (scp) ->
    opts = 
      help : 'launch the server in daemon mode'
    name = 'daemon'
    sub = scp.addParser name, opts
    return [ name ]

  #------------------------------

  run : (cb) ->
    if not @argv.debug and not @argv.foreground
      await @daemonize defer()
    if ok
      await @init defer ok
    if @argv.debug and ok
      await @server.run defer()
    cb ok

#=========================================================================
