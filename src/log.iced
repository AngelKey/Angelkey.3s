
colors = require 'colors'

#=========================================================================

exports.log = log = (msg) - > console.log msg
exports.warn = warn = (msg) -> log colors.magenta msg
exports.error = error = (msg) -> log colors.bold colors.red msg
exports.info = info = (msg) -> log msg

#=========================================================================
