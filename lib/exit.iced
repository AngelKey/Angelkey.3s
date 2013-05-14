fs = require 'fs'
log = require './log'

#=========================================================================

exports.ExitHandler = class ExitHandler

  constructor : ({@sockname}) ->
    @_ran_hook = false
    @setup()

  hook : () ->
    if not @_ran_hook 
      @_ran_hook = true
      await fs.unlink @sockname, defer err
      log.error "Could not remove #{sockname}: #{err}"

  on_exit : () ->
    @hook()

  do_exit : (rc) ->
    @on_exit()
    process.exit rc

  setup : () ->
    process.once 'exit', () => @on_exit()
    process.once 'SIGINT', () => @do_exit -1 
    process.once 'SIGTERM', () => @do_exit -2


#=========================================================================
