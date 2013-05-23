
log = require './log'

#================================================

# Error short-circuit connector
exports.make_esc = make_esc = (gcb, op) -> (lcb) ->
  (err, args...) ->
    if not err? then lcb args...
    else if not gcb.__esc
      gcb.__esc = true
      log.error "In #{op}: #{err}"
      gcb err

#================================================

# A class-based Error short-circuiter; output OK
exports.EscOk = class EscOk
  constructor : (@gcb) ->

  bailout : () ->
    if @gcb
      t = @gcb
      @gcb = null
      t false

  check_ok : (cb) ->
    (ok, args...) =>
      if not ok then @bailout()
      else cb args...

  check_err : (cb) ->
    (err, args...) =>
      if err?
        log.error err
        @bailout()
      else cb args...

  check_non_null : (cb) ->
    (a0, args...) =>
      if not a0? then @bailout()
      else cb args...

#================================================

exports.EscErr = class EscErr
  constructor : (@gcb) ->

  finish : (err) ->
    if @gcb
      t = @gcb
      @gcb = null
      t err

  check_ok : (what, cb) ->
    (ok, args...) ->
      if not ok then @finish new Error "#{what} failed"
      else cb args...

  check_err : (cb) ->
    (err, args...) ->
      if err?
        log.error err
        @finish err
      else cb args...

#================================================


