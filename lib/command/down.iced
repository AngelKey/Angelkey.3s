path = require 'path'
fs = require 'fs'
{Base} = require './base'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv
ProgressBar = require 'progress'
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

    sub = scp.addParser 'down', opts
    add_option_dict sub, @OPTS
    sub.addArgument ["file"], { nargs : 1 }

  #------------------------------

  run : (cb) ->
    downloader = new Downloader {
      filename : @argv.file[0]
      base : @
    }
    await downloader.run defer ok 


    ok = true
    await @find_file defer ok     if ok
    await @initiate_job defer ok  if ok
    await @wait_for_job defer ok  if ok
    await @download_file defer ok if ok 
    await @finalize_file defer ok if ok
    cb ok

  #------------------------------

  find_file : (cb) ->

#=========================================================================

