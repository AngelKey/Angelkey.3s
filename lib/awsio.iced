

#=========================================================================

exports.Base = class Base

  constructor : ({@base}) ->
    console.log @base.config

  #--------------

  glacier : -> @base.aws.glacier
  dynamo  : -> @base.aws.dynamo
  simpledb : -> @base.aws.simpledb
  iam     : -> @base.aws.iam
  vault   : -> @base.config.vault()
  interactive : -> @base.argv.interactive

#=========================================================================
