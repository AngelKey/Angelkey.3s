
fs = require 'fs'

##======================================================================

exports.open = ({filename, write, mode, bufferSize}, cb) ->
  mode or= 0640
  bufferSize or= 1024*1024
  flags = if write then "w" else "r"
  ret = null
  await fs.open filename, flags, mode, defer err, fd
  unless err?
    opts = { fd, bufferSize }
    f = if write then fs.createWriteStream else fs.createReadStream
    ret = f filename, opts
  cb err, ret
  
##======================================================================

