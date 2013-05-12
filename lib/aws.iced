
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

#=========================================================================

exports.AwsWrapper = class AwsWrapper

  constructor : () ->

  init : (config) ->
    AWS.config.update config
    @glacier = new AWS.Glacier()
    @dynamo = new AWS.DynamoDB { apiVersion : '2012-08-10' }
    @simpledb = new AWS.SimpleDB { apiVersion : '2009-04-15' }
    @iam = new AWS.IAM { apiVersion: '2010-05-08' }
    @sns = new AWS.SNS { apiVersion: '2010-03-31' }
    @sqs = new AWS.SQS { apiVersion: '2012-11-05' }



  new_resource : (opts) ->
    return new Resource opts

#=========================================================================

console.log (new AwsWrapper).url_to_arn 'https://sqs.us-west-2.amazonaws.com/230893760634/mkbkp-mba-queue'