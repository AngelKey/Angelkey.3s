{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
mycrypto = require '../crypto'
{Downloader} = require '../downloader'
{status} = require '../constants'
{Launcher} = require '../launch'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  OPTS :
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
      action : 'storeTrue'

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
        opts:
          output_path : @argv.output
          no_decrypt : @argv.no_decrypt
          encrypted_output : @argv.encrypted_output
      }
      await downloader.find_file defer rc
      ok = (rc is status.OK) 

    if ok and not @argv.no_decrypt
      await downloader.get_key_material defer ok
      if not ok
        log.error "Failed to derive key material for decryption"

    if ok
      launcher = new Launcher { @config }
      await launcher.run defer ok, cli
      if not ok
        log.error 'Failed to launch or connect to daemon process'

    if ok
      downloader.send_download_to_daemon cli, defer ok

    cb ok

  #------------------------------

#=========================================================================

