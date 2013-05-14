
{fork} = require 'child_process'
path = require 'path'

#=========================================================================

exports.rmkey = (obj, key) ->
  ret = obj[key]
  delete obj[key]
  ret

exports.daemon = (main, args) ->
  icmd = path.join __dirname, "..", "node_modules", ".bin", "iced"
  fork main, args, { execPath : icmd }