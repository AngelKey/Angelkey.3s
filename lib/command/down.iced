{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
mycrypto = require '../crypto'
{Downloader} = require '../downloader'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  add_subcommand_parser : (scp) ->
    opts = 
      aliases : [ 'download' ]
      help : 'download an archive from the server'
    name = 'down'
    sub = scp.addParser name, opts
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

