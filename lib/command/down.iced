{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
mycrypto = require '../crypto'
{Downloader} = require '../downloader'
{status} = require '../constants'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  OPTS :
    W :
      alias : "no-wait"
      action : "storeTrue"
      help : "don't wait, just start the job, and make the same call to check back later"
    o :
      alias : "output"
      help : "path to output the file to (if not its original location)"
    x : 
      alias : 'encrypted-output'
      help : "dump the encrypted output to the given path"
      action : 'storeTrue'
    E :
      alias : 'no-decrypt'
      help : "don't even try to decrypt the file"

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
      await downloader.find_file defer rc
      ok = (rc is status.OK) 

    if ok and not @argv.encrypted_output
      await downloader.get_key_material defer ok

    cb ok

  #------------------------------

#=========================================================================

