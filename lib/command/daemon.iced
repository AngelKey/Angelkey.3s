
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
    console.log "A"
    ch = daemon [ "server", "--daemon" ]
    await ch.once 'message', defer msg
    for m in msg.err?
      log.error "Error launching daemon: #{m}"
    log.info "Server launched -> #{JSON.stringify msg}"
    cb msg.ok

#=========================================================================
