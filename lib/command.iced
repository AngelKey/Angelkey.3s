
{AwsWrapper} = require './aws'
{Config} = require './config'
log = require './log'
{PasswordManager} = require './pw'

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

    ok = true

    if @argv.h or not @check_args()
      opti.showHelp()
      ok = false

    ok

  #-------------------

  need_aws : () -> true
  check_args : () -> true

  #-------------------

  init : (usage, opts, cb) ->
    ok = @parse_options usage, opts 
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

