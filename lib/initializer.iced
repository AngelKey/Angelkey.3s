#!/usr/bin/env iced

log = require './log'


#=========================================================================

exports.Initializer = class Initializer

  #--------------

  constructor : ({@aws, @vault}) ->

  #--------------

  make_iam_user : (cb) ->
    arg = { UserName : @name }
    await @iam().createUser arg, defer err
    ok = true
    if err?
      ok = false
      log.error "Error in making user '#{@name}': #{err}"
    if ok
      await @iam().createAccessKey arg, defer err, res
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
      @sns = @aws.makeResource { arn : res.TopicArn }
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
      @sqs = @aws.newResource { url : res.QueueUrl }

    # Now fetch the attributes on this thing that we need access
    # to or eventually need to twiddle
    policy = null
    if ok
      arg = 
        QueueUrl : @sqs.url
        AttributeNames : [ 'Policy', 'QueueArn' ] 
      await @aws.sqs.getQueueAtttributes arg, defer err, res
      if err?
        ok = false
        log.error "Error getting SQS attributes: #{err}"
      else
        policy = res.Policy
        @sqs.arn = res.QueueArn

    # Allow the SNS service to write to this...
    if ok and policy?
      new_statement = 
        Effect : "Allow"
        Principal : AWS : "*"
        Action : "SQS:SendMessage"
        Resource : @sqs.arn
        Condition : ArnEquals : "aws:SourceArn" : @sns.arn
      policy.Statement.push new_statement
      arg = 
        QueueUrl : @sqs.url
        Policy : policy
      await @aws.sqs.setQueueAttribute arg, defer err, res
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

  #--------------

  make_vault : (cb) ->


  #--------------

  run : (cb) ->
    ok = true


  #--------------

  init_simpledb : (cb) ->
    arg = 
      DomainName : @vault()
    await @simpledb().createDomain arg, defer err, res
    ok = true
    if err?
      log.error "In creating domain #{@vault()}: #{err}"
      ok = false
    else
      console.log res
    cb ok

  #--------------

#=========================================================================

