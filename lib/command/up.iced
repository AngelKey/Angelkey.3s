{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
{Uploader} = require '../uploader'
{Encryptor} = require '../file'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  OPTS : 
    E : 
      alias : "no-encrypt"
      action : "storeTrue"
      help : "turn off encryption"

  #------------------------------
  
  add_subcommand_parser : (scp) ->
    opts = 
      aliases : [ 'upload' ]
      help : 'upload an archive to the server'
    name = 'up'

    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    sub.addArgument ["file"], { nargs : 1 }
    return opts.aliases.concat [ name ]

  #------------------------------

  make_eng : (d) -> new Encryptor d

  #------------------------------
  
  run : (cb) -> 
    @enc = not @argv.no_encrypt
    await @init2 { infile : true, @enc }, defer ok

    if ok
      ins = @input.stream
      @input.enc = if @enc? then @enc.version() else 0
      if @enc?
        @input.stream = ins.pipe @enc

      uploader = new Uploader {
        base : @
        file: @input
      }
      await uploader.run defer ok
      if not ok
        log.error "upload to glacier failed"
    cb ok 

  #------------------------------

#=========================================================================

