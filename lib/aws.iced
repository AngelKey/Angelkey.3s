
AWS = require 'aws-sdk'

#=========================================================================

exports.AwsWrapper = class AwsWrapper

  constructor : () ->

  init : (config) ->
    @config = config
    @glacier = new AWS.Glacier()
    @dynamo = new AWS.DynamoDB({apiVersion : '2012-08-10'})

#=========================================================================

