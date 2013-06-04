{Base} = require './base'
log = require '../log'
{add_option_dict} = require './argparse'
{Uploader} = require '../uploader'
{Encryptor,PlainEncoder} = require '../file'
{EscOk} = require 'iced-error'

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

  make_eng : (d) -> 
    d.blocksize = Uploader.BLOCKSIZE
    klass = if @enc then Encryptor else PlainEncoder
    new klass d

  #------------------------------

  make_outfile : (cb) ->
    @uploader = new Uploader { base : @, file : @infile }
    cb null, @uploader

  #------------------------------
  
  run : (cb) -> 
    esc = new EscOk cb, "Uploader::run"
    @enc = not @argv.no_encrypt
    await @init2 { infile : true, @enc }, esc.check_ok(defer(), E.InitError)
    await @uploader.init esc.check_ok(defer(), E.AwsError)
    await @run esc.check_err defer()
    await @uploader.finish esc.check_ok(defer(), E.IndexError)
    cb true

  #------------------------------

#=========================================================================

