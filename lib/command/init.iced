
{Base} = require './base'
{Initializer} = require '../initializer'
{add_option_dict} = require './argparse'
read = require 'read'
log = require '../log'

#=========================================================================

exports.Command = class Command extends Base

  #------------------------------

  OPTS : 
    o :
      alias : 'output'
      help : 'the output config file to write (defaults to ~/.mkb.conf'
    A :
      alias : 'access-key-id'
      help : 'the accessKeyId for an admin AWS user'
    r : 
      alias : 'region'
      help : 'the AWS region to work in'
    S : 
      alias : 'secret-access-key'
      help : 'the secreteAccessKey for an admin AWS user'
    v :
      alias : 'vault'
      help : 'the vault name to create'

  #------------------------------

  get_opt_or_prompt : ({name, desc}, cb) ->
    desc = name unless desc?
    val = @argv[name]
    err = null
    until val? or err?
      await read { prompt: "#{desc}> " }, defer err, val
      if err?
        log.error "Error in getting #{desc}: #{err}"
    cb err, val

  #------------------------------

  load_config_value : ({name, desc, key}, cb) ->
    await @get_opt_or_prompt {name, desc}, defer err, val
    @config.set key, val if val?
    cb not err?

  #------------------------------

  load_config : (cb) ->
    ok = true
    fields = [{
      name : 'email'
      desc : 'your primary email address'
      key : 'email'
    },{
      name : 'region'
      desc : 'AWS region (like "us-west-1")'
      key : 'aws.region'
    },{
      name : 'vault'
      desc : 'vault name'
      key : 'vault'
    },{
      name : 'access_key_id'
      desc : 'access key id'
      key : 'aws.accessKeyId'
    },{
      name : 'secret_access_key'
      desc : 'secret access key'
      key : 'aws.secretKeyId'
    }]

    for d in fields
      await @load_config_value d, defer ok 

    @config.loaded = ok
    console.log @config.json

    cb ok

  #------------------------------

  add_subcommand_parser : (scp) ->
    opts = 
      help : 'initialize AWS for this user'
    name = 'init'
    sub = scp.addParser name, opts
    add_option_dict sub, @OPTS
    return [ name ]

  #------------------------------

  init : (cb) ->
    await @load_config defer ok
    await super defer ok if ok
    cb ok

  #------------------------------

  run : (cb) ->
    await @init defer ok
    if ok 
      i = new Initializer { base : @ }
      await i.run defer ok 
    cb ok

  #------------------------------

#=========================================================================

