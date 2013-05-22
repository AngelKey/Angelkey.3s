
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


