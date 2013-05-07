
optim = require 'optimist'
{Base} = require './base'
path = require 'path'
fs = require 'fs'
log = require '../log'
{ArgumentParser} = require 'argparse'
{add_option_dict} = require './argparse'

##=======================================================================

read_version = (cb) ->
  f = path __dirname, '..', '..', 'package.json'
  await fs.readFile f, "r", defer err, data
  if err?
    log.error "cannot open package.json: #{err}"
  else
    try 
      obj = JSON.parse data
      ret = obj.version
      unless ret?
        log.error "package.json doesn't say which 'version' we are"
    catch e
      log.error "Bad json in package.json: #{e}"
  cb ret

##=======================================================================

class Main

  #---------------------------------

  constructor : ->
    @commands = {}

  #---------------------------------

  init : (cb) ->
    ok = true
    await read_version defer v
    ok = false unless v?

    if ok
      @ap = new ArgumentParser 
        addHelp : true
        version : v
        description : 'Backup files to AWS glacier'
        prog : process.argv[1]

      ok = @add_subcommands()
    cb ok

  #---------------------------------

  add_subcommands : () ->

    # Add the base options that are useful for all subcommands
    add_option_dict @ap, Base.OPTS

    list = [ 
      "enc",
      "dec"
    ]

    subparsers = @ap.addSubparsers {
      title : 'subcommands'
      dest : 'subcommand_name'
    }

    @commands = {}

    for m in list
      mod = require './#{m}'
      obj = new mod.Command()
      obj.add_subcommand_parser subparsers
      @commands[m] = obj

    true

  #---------------------------------

  parse_args : () ->
    @argv = @ap.parseArgs process.argv[2...]

  #---------------------------------

  run : () ->
    ok = @parse_args()
    ok = true
    if process.argv.length >= 3 and (obj = @commands[process.argv[2]])?
      obj = maker()
      await obj.run process.argv[2...], defer ok
    else
      @help()
      ok = false
    process.exit if ok then 0 else -2

##=======================================================================

exports.run = () -> (new Main).run()

##=======================================================================

