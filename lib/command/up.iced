path = require 'path'
fs = require 'fs'
{Base} = require './base'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv
ProgressBar = require 'progress'
log = require '../log'
{add_option_dict} = require './argparse'
mycrypto = require '../crypto'
{Uploader} = require '../uploader'

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
  
  init : (cb) ->
    await super defer ok
    if ok
      await @base_open_input @argv.file[0], defer err, @input
      if err?
        log.error "In opening input file: #{err}"
        ok = false 
    cb ok 

  #------------------------------
  
  run : (cb) -> 
    await @init defer ok

    if ok and not @argv.no_encrypt
      @enc = new mycrypto.Encryptor { @pwmgr, stat : @input.stat }
      await @enc.init defer ok
      unless ok
        log.error "Could not setup keys for encryption"
    else 
      @eng = null


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

