
{AwsWrapper} = require './aws'
{Config} = require './config'
log = require './log'
{PasswordManager} = require './pw'

#=========================================================================

class Base

  #-------------------

  constructor : () ->
    @config = new Config()
    @aws    = new AwsWrapper()
    @pwmgr  = new PasswordManager()

  #-------------------

  parse_options : (usage, opts_passed = {}) ->
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

    opti = require('optimist').options(opts).options(opts_passed).usage(usage)

    @argv = opti.argv
    console.log @argv

    ok = true

    if @argv.h
      opti.showHelp()
      ok = false

    ok

  #-------------------

  init : (usage, opts, cb) ->
    ok = @parse_options usage, opts     
    await @config.load @argv.c, defer ok  if ok
    ok = @aws.init @config.aws            if ok
    ok = @_init_pwmgr()                   if ok
    cb ok

  #-------------------

  _init_pwmgr : () ->
    pwopts =
      passwords  : @password()
      no_prompt  : @argv.P
      salt       : @salt_or_email()

    @pwmgr.init pwopts

  #-------------------

  dynamo  : () -> @aws.dynamo
  glacier : () -> @aws.glacier

  #-------------------

  password : () -> @argv.p or @config.password
  email    : () -> @argv.e or @config.email
  salt     : () -> @argv.s or @config.salt
  salt_or_email : () -> @salt() or @email()

#=========================================================================

