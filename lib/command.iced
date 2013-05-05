
{AwsWrapper} = require './aws'
{Config} = require './config'
log = require './log'
{PasswordManager} = require './pw'
base58 = require '../lib/base58'
crypto = require 'crypto'
mycrypto = require '../lib/crypto'
myfs = require '../lib/fs'
fs = require 'fs'

#=========================================================================

pick = (args...) ->
  for a in args
    return a if a?
  return null

#=========================================================================

dmerge = (dl) ->
  ret = {}
  for d in dl
    for k,v of d
      ret[k] = v
  ret

#=========================================================================

exports.Base = class Base

  #-------------------

  constructor : () ->
    @config = new Config()
    @aws    = new AwsWrapper()
    @pwmgr  = new PasswordManager()
    @opts_annex = []

  #-------------------

  add_opts : (o) -> @opts_annex.push o

  #-------------------

  parse_options : (usage) ->
    opts = 
      e :
        alias : 'email'
        describe : 'email address, used for salting passwords & other things'
      s : 
        alias : 'salt'
        describe : 'salt used as salt and nothing else; overrides emails'
      p :
        alias : 'password'
        describe : 'password used for encryption / decryption'
      P :
        boolean : true
        alias : 'no-prompt'
        describe : "Don't prompt for a password if we were going to"
      n : 
        boolean : true
        alias : 'no-encryption'
        describe : "don't use encryption when uploading / downloading"
      c : 
        alias : 'config-file'
        describe : 'a configuration file (rather than ~/.mkbkp.conf)'
      h : 
        boolean : true
        alias : 'help'
        describe : 'print this help message'

    opts = dmerge [ opts ].concat @opts_annex

    opti = require('optimist').options(opts).usage(usage)

    @argv = opti.argv

    ok = true

    if @argv.h or not @check_args()
      opti.showHelp()
      ok = false

    ok

  #-------------------

  need_aws : () -> true
  check_args : () -> true

  #-------------------

  init : (usage, cb) ->
    ok = @parse_options usage
    await @config.load @argv.c, defer ok  if ok
    ok = @aws.init @config.aws            if ok and @need_aws()
    ok = @_init_pwmgr()                   if ok
    cb ok

  #-------------------

  _init_pwmgr : () ->
    pwopts =
      password   : @password()
      no_prompt  : @argv.P
      salt       : @salt_or_email()

    @pwmgr.init pwopts

  #-------------------

  dynamo  : () -> @aws.dynamo
  glacier : () -> @aws.glacier

  #-------------------

  password : () -> pick @argv.p, @config.password()
  email    : () -> pick @argv.e, @config.email()
  salt     : () -> pick @argv.s, @config.salt()
  salt_or_email : () -> pick @salt(), @email()

#=========================================================================

exports.CipherBase = class CipherBase extends Base
   
  #-----------------

  OPTS :
    o : 
      alias : "output"
      describe : "output file to write to"
    r :
      alias : "remove"
      describe : "remove the original file after encryption"
      boolean : true
    x :
      alias : "extension"
      describe : "encrypted file extension"

  #-----------------

  USAGE : "Usage: $0 [opts] <infile>"

  #-----------------

  need_aws : -> false

  #-----------------

  check_args : () ->
    if @argv._.length isnt 1
      log.warn "Need an input file argument"
      false
    else true

  #-----------------
   
  constructor : () ->
    super()
    @add_opts @OPTS

  #-----------------

  file_extension : () -> @argv.x or @config.file_extension()

  #-----------------

  strip_extension : (fn) ->
    v = fn.split "."
    x = @file_extension()
    l = v.length
    if v[l-1] is x then v[0...l].join '.'
    else null

  #-----------------

  tmp_filename : (stem) ->
    ext = base58.encode crypto.rng 8
    [stem, ext].join '.'

  #-----------------

  open_output : (cb) ->
    ok = true
    if (ofn = @output_filename())?
      @outfn = ofn
      @tmpfn = @tmp_filename @outfn
      await myfs.open { filename : @tmpfn, write : true }, defer err, ostream
      if err?
        log.error "Error opening temp outfile #{@tmpfn}: #{err}"
        ok = false
    else
      @outfn = "<stdout>"
      ostream = process.stdout 
    cb ok, ostream

  #-----------------

  # Maybe eventually decryption can do something here...
  patch_file_metadata : (cb) -> cb()

  #-----------------

  cleanup_on_success : (cb) ->
    await fs.rename @tmpfn, @outfn, defer err
    ok = true
    if err?
      log.error "Problem in file rename: #{err}"
      ok = false
    if ok and @argv.r
      await fs.unlink @infn, defer err
      if err?
        log.error "Error in removing original file #{@infn}: #{err}"
        ok = false
    if ok
      await @patch_file_metadata defer()
    cb ok
    
  #-----------------

  cleanup_on_failure : (cb) ->
    ok = true
    await fs.unlink @tmpfn, defer err
    if err?
      log.warn "cannot remove temporary file #{@tmpfn}: #{err}"
      ok = false
    cb ok

  #-----------------

  cleanup : (ok, cb) ->
    if ok 
      await @cleanup_on_success defer ok
    else
      @ostream.close() if @ostream?
      @istream.close() if @istream?
      await @cleanup_on_failure defer()
    cb()

  #-----------------

  init : (cb) ->
    await super @USAGE, defer ok
    if ok
      @infn = @argv._[0]
      await myfs.open { filename :  @infn }, defer err, @istream, @stat
      ok = false if err?
    if ok
      await @open_output defer ok, @ostream
    cb ok
  
  #-----------------

  run : (cb) ->
    console.log "A #{ok}"
    await @init defer ok
    console.log "B #{ok}"

    opened = false

    if ok
      opened = true
      @eng = @make_eng { @pwmgr, @stat }
      await @eng.init defer ok
      if not ok
        log.error "Could not setup keys for encryption/decryption"

    console.log "C #{ok}"
    if ok
      @istream.pipe(@eng).pipe(@ostream)
      await @istream.once 'end', defer()
      await @ostream.once 'finish', defer()

    console.log "D #{ok}"
    if ok
      [ok, err] = @eng.validate()
      if not ok
        log.error "Final validation error: #{err}"

    console.log "E #{ok}"

    await @cleanup ok, defer() if opened
    cb ok

#=========================================================================

