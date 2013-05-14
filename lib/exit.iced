fs = require 'fs'
log = require './log'

#=========================================================================

exports.ExitHandler = class ExitHandler

  constructor : ({@config}) ->
    @_ran_hook = false
    @setup()
    @_cb = null

  hook : () ->
    if not @_ran_hook 
      @_ran_hook = true
      for f in [ @config.sockfile(), @config.pidfile() ]
        await fs.unlink f, defer err
        log.error "Could not remove #{f}: #{err}"

  on_exit : () ->
    @hook()
    @_cb?()

  call_on_exit : (c) -> @_cb = c

  do_exit : (rc) ->
    @on_exit()
    process.exit rc

  setup : () ->
    process.once 'exit', () => @on_exit()
    process.once 'SIGINT', () => @do_exit -1 
    process.once 'SIGTERM', () => @do_exit -2


#=========================================================================
