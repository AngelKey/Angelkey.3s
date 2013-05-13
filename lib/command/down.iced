{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
mycrypto = require '../crypto'
{Downloader} = require '../downloader'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  OPTS :
    W :
      alias : "no-wait"
      action : "storeTrue"
      help : "don't wait, just start the job, and make the same call to check back later"

  #------------------------------


  add_subcommand_parser : (scp) ->
    opts = 
      aliases : [ 'download' ]
      help : 'download an archive from the server'
    name = 'down'
    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    sub.addArgument ["file"], { nargs : 1 }
    return opts.aliases.concat [ name ]

  #------------------------------

  init : (cb) ->
    await super defer ok
    cb ok

  #------------------------------

  run : (cb) ->
    await @init defer ok

    if ok 
      downloader = new Downloader {
        filename : @argv.file[0]
        base : @
      }
      await downloader.run defer ok 
    cb ok

  #------------------------------

#=========================================================================

