
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
      key : 'aws.secretAccessKey'
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
    console.log "A #{ok}"
    await @load_config defer ok
    console.log "B #{ok}"
    await super defer ok if ok
    console.log "C #{ok}"
    @vault = @config.vault()
    @name = "mkp-#{@vault}"
    cb ok

  #--------------

  make_iam_user : (cb) ->
    arg = { UserName : @name }
    await @aws.iam.createUser arg, defer err
    ok = true
    if err?
      ok = false
      log.error "Error in making user '#{@name}': #{err}"
    if ok
      await @aws.iam.createAccessKey arg, defer err, res
      if err?
        ok = false
        log.error "Error in creating access key: #{err}"
      else
        {@AccessKeyId, @SecretAccessKey} = res
    cb ok

  #--------------

  make_sns : (cb) -> 
    await @aws.sns.createTopic { Name : @name }, defer err, res
    ok = true
    if err?
      log.error "Error making notification queue: #{err}"
      ok = false
    else
      log.info "Response from SNS.createTopic: #{JSON.stringify res}"
      @sns = @aws.new_resource { arn : res.TopicArn }
    cb ok

  #--------------

  make_sqs : (cb) ->

    # First make the queue
    await @aws.sqs.createQueue { QueueName : @name }, defer err, res
    ok = true
    if err?
      ok = false
      log.error "Error creating queue #{@name}: #{err}"
    else
      log.info "Reponse from SQS.createQueue: #{JSON.stringify res}"
      @sqs = @aws.new_resource { url : res.QueueUrl }

    # Allow the SNS service to write to this...
    if ok
      policy = 
        Statement: [{
          Effect : "Allow"
          Principal : AWS : "*"
          Action : "SQS:SendMessage"
          Resource : @sqs.arn
          Condition : ArnEquals : "aws:SourceArn" : @sns.arn
        }]
      arg = 
        QueueUrl : @sqs.url
        Attributes:
          Policy : JSON.stringify policy
      console.log "setQAttrs: "
      console.log arg
      await @aws.sqs.setQueueAttributes arg, defer err, res
      if err?
        log.error "Error setting Queue attributes with #{JSON.stringify arg}: #{err}"
        ok = false

    # Allow our user to manipulate the Queue however it pleases..
    if ok?
      read_policy =
        Statement : [{
          Action : [ "sqs:*" ]
          Effect : "Allow"
          Resource : [ @sqs.arn ]
        }]
      policy_name = "#{@name}-sqs-read-policy"
      arg =
        UserName : @name
        PolicyName : policy_name
        PolicyDocument : JSON.stringify read_policy
      await @aws.iam.putUserPolicy arg, defer err, data
      if err?
        log.error "Error setting read policy on queue #{JSON.stringify arg}: #{err}"
        ok = false

    cb ok

  #------------------------------

  run : (cb) ->
    await @init defer ok
    await @make_iam_user defer ok   if ok
    await @make_sns      defer ok   if ok
    await @make_sqs      defer ok   if ok
    #await @make_glaicer  defer ok   if ok
    #await @init_simpledb defer ok   if ok
    cb ok

  #------------------------------

#=========================================================================

