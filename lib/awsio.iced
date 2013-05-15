

#=========================================================================

exports.Base = class Base

  constructor : ({@base}) ->

  #--------------

  glacier : -> @base.aws.glacier
  dynamo  : -> @base.aws.dynamo
  sdb     : -> @base.aws.sdb
  iam     : -> @base.aws.iam
  vault   : -> @base.config.vault()
  interactive : -> @base.argv.interactive
  pwmgr   : -> @base.pwmgr

#=========================================================================
