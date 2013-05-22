
{AwsWrapper} = require '../aws'
{Config} = require '../config'
log = require '../log'
{PasswordManager} = require '../pw'
base58 = require '../base58'
crypto = require 'crypto'
mycrypto = require '../crypto'
myfs = require '../fs'
fs = require 'fs'
{rmkey} = require '../util'
{add_option_dict} = require './argparse'
{Infile, Outfile} = require '../file'

#=========================================================================

pick = (args...) ->
  for a in args
    return a if a?
  return null

#=========================================================================

exports.Base = class Base

  #-------------------

  constructor : () ->
    @config = new Config()
    @aws    = new AwsWrapper()
    @pwmgr  = new PasswordManager()

  #-------------------

  set_argv : (a) -> @argv = a

  #-------------------

  @OPTS :
    e :
      alias : 'email'
      help : 'email address, used for salting passwords & other things' 
    s :
      alias : 'salt'
      help : 'salt used as salt and nothing else; overrides emails'
    p : 
      alias : 'password'
      help : 'password used for encryption / decryption'
    c : 
      alias : 'config'
      help : 'a configuration file (rather than ~/.mkb.conf)'
    i : 
      alias : "interactive"
      action : "storeTrue"
      help : "interactive mode"

  #-------------------

  need_aws : () -> true

  #-------------------

  init : (cb) ->

    if @config.loaded
      # The 'init' subcommand will load in an init object that it 
      # invents out of thin air, so no need to read from the FS
      ok = true
    else
      await @config.find @argv.config, defer fc
      if fc  
        await @config.load defer ok
      else if @need_aws()
        log.error "cannot find config file #{@config.filename}; needed for aws"
        ok = false

    ok = @aws.init @config.aws()         if ok and @need_aws()
    ok = @_init_pwmgr()                  if ok
    cb ok

  #-------------------

  _init_pwmgr : () ->
    pwopts =
      password    : @password()
      salt        : @salt_or_email()
      interactive : @argv.interactive

    @pwmgr.init pwopts

  #-------------------

  dynamo  : () -> @aws.dynamo
  glacier : () -> @aws.glacier

  #-------------------

  password : () -> pick @argv.password, @config.password()
  email    : () -> pick @argv.email, @config.email()
  salt     : () -> pick @argv.salt, @config.salt()
  salt_or_email : () -> pick @salt(), @email()

  #----------------

  base_open_input : (fn, cb) ->
    await Infile.open fn, defer err, file
    cb err, file

#=========================================================================

exports.CipherBase = class CipherBase extends Base
   
  #-----------------

  OPTS :
    o :
      alias : "output"
      help : "output file to write to"
    r :
      alias : "remove" 
      action : 'storeTrue'
      help : "remove the original file after encryption"
    x :
      alias : "extension"
      help : "encrypted file extension"

  #-----------------

  need_aws : -> false

  #-----------------

  file_extension : () -> @argv.x or @config.file_extension()

  #-----------------

  strip_extension : (fn) -> myfs.strip_extension fn, @file_extension()

  #-----------------

  open_output : (cb) ->
    await Outfile.open { target, @output_filename() },  defer err, output
    cb err, output

  #-----------------

  # Maybe eventually decryption can do something here...
  patch_file_metadata : (cb) -> cb()

  #-----------------

  cleanup_on_success : (cb) ->
    await fs.rename @output.filename, @outfn, defer err
    ok = true
    if err?
      log.error "Problem in file rename: #{err}"
      ok = false
    if ok and @argv.r
      await fs.unlink @input.filename, defer err
      if err?
        log.error "Error in removing original file #{@input.file}: #{err}"
        ok = false
    if ok
      await @patch_file_metadata defer()
    cb ok
    
  #-----------------

  cleanup_on_failure : (cb) ->
    ok = true
    await fs.unlink @output.tmpfn, defer err
    if err?
      log.warn "cannot remove temporary file #{@output.tmpfn}: #{err}"
      ok = false
    cb ok

  #-----------------

  cleanup : (ok, cb) ->
    if ok 
      await @cleanup_on_success defer ok
    else
      @output?.close()
      @input?.close()
      await @cleanup_on_failure defer()
    cb()

  #-----------------

  init : (cb) ->
    await super defer ok
    if ok
      await @base_open_input argv.file[0], defer err, @input
      if err?
        log.error "In opening input file: #{err}"
        ok = false
    if ok
      await @open_output defer err, @output
      if err?
        log.error "In opening output file: #{err}"
        ok = false
    cb ok
  
  #-----------------

  add_subcommand_parser : (scp) ->
    # Ask the child class for the subcommand particulars....
    scd = @subcommand()
    name = rmkey scd, 'name'
    opts = rmkey scd, 'options'

    sub = scp.addParser name, scd
    add_option_dict sub, @OPTS
    add_option_dict sub, opts if opts?

    # There's an optional input filename, since stdin can work too
    sub.addArgument ["file"], { nargs : 1 } 

    return scd.aliases.concat [ name ]

  #-----------------

  run : (cb) ->
    await @init defer ok

    opened = false

    if ok
      opened = true
      @eng = @make_eng { @pwmgr, stat : @input.stat }
      await @eng.init defer ok
      if not ok
        log.error "Could not setup keys for encryption/decryption"

    if ok
      @input.stream.pipe(@eng).pipe(@output.stream)
      await @input.stream.once 'end', defer()
      await @output.stream.once 'finish', defer()

    if ok
      [ok, err] = @eng.validate()
      if not ok
        log.error "Final validation error: #{err}"

    await @cleanup ok, defer() if opened
    cb ok

#=========================================================================

