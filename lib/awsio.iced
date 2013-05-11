

#=========================================================================

exports.Base = class Base

  constructor : ({@base}) ->

  #--------------

  glacier : -> @base.aws.glacier
  dynamo  : -> @base.aws.dynamo
  vault   : -> @base.config.vault()

#=========================================================================
