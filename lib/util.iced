
{fork} = require 'child_process'
path = require 'path'

#=========================================================================

exports.rmkey = (obj, key) ->
  ret = obj[key]
  delete obj[key]
  ret

exports.daemon = (args) ->
  icmd = path.join __dirname, "..", "node_modules", ".bin", "iced"
  fork process.argv[1], args, { execPath : icmd, detatched : true }
