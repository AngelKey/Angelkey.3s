
colors = require 'colors'
winston = require 'winston'

#=========================================================================

exports.log = log = (msg) -> info msg
exports.warn = warn = (msg) -> winston.warn colors.magenta msg
exports.error = error = (msg) -> winston.error colors.bold colors.red msg
exports.info = info = (msg) -> winston.info colors.green msg

#=========================================================================

exports.daemonize = (file) ->
  winston.add winston.transports.File, { filename : file }
  winston.remove winston.transports.Console

#=========================================================================
