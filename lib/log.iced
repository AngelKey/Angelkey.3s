
colors = require 'colors'
winston = require 'winston'
rpc = require('framed-msgpack-rpc').log

#=========================================================================

exports.log = log = (msg) -> info msg
exports.warn = warn = (msg) -> winston.warn colors.magenta msg
exports.error = error = (msg) -> winston.error colors.bold colors.red msg
exports.info = info = (msg) -> winston.info colors.green msg
exports.debug = info = (msg) -> winston.debug msg

#=========================================================================

exports.daemonize = (file) ->
  winston.add winston.transports.File, { filename : file }
  winston.remove winston.transports.Console

#=========================================================================

# Make a winston-aware version of the RPC logger
class Logger extends rpc.Logger

  _log : (m, l, ohook) ->
    parts = []
    parts.push @prefix if @prefix?
    parts.push m
    msg = parts.join " "
    map = 
      D : "debug"
      I : "info"
      W : "warn"
      E : "error"
      F : "fatal"
    l = map[l] or "warn"
    exports[l] msg

#=========================================================================

rpc.set_default_logger_class Logger

#=========================================================================

