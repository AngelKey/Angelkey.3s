
AWS = require 'aws-sdk'
url = require 'url'

#=========================================================================

exports.Resource = class Resource

  constructor : ({@url, @arn}) ->
    @arn = Resource.url_to_arn @url if not @arn? and @url?

  @url_to_arn : (u) ->
    uparts = url.parse u
    host = uparts.host.split '.'
    path = uparts.path.split '/'
    aparts = [ 'arn', 'aws'].concat( host[0...2]).concat(path[1...3])
    aparts.join ':'

  toString : () -> @arn

#=========================================================================

exports.AwsWrapper = class AwsWrapper

  constructor : () ->

  init : (@config) ->
    AWS.config.update config
    @glacier = new AWS.Glacier()
    @dynamo = new AWS.DynamoDB { apiVersion : '2012-08-10' }
    @sdb = new AWS.SimpleDB { apiVersion : '2009-04-15' }
    # Iam only works for us-east-1 as far as I can tell...
    @iam = new AWS.IAM { apiVersion: '2010-05-08', region : 'us-east-1' }
    @sns = new AWS.SNS { apiVersion: '2010-03-31' }
    @sqs = new AWS.SQS { apiVersion: '2012-11-05' }

  new_resource : (opts) ->
    return new Resource opts

#=========================================================================

