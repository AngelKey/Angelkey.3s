
fs = require 'fs'
log = require './log'
C = require 'constants'

##======================================================================

exports.File = class File

  constructor : ({@stream, @stat, @realpath, @filename, @fd}) ->

  close : () -> @stream?.close()

##======================================================================

exports.open = ({filename, write, mode, bufferSize}, cb) ->
  mode or= 0o640
  bufferSize or= 1024*1024
  stat = null
  err = null
 
  flags = if write then (C.O_WRONLY | C.O_TRUNC | C.O_EXCL | C.O_CREAT)
  else C.O_RDONLY

  unless write
    await fs.stat filename, defer err, stat
    if err?
      log.warn "Failed to access file #{filename}: #{err}"
  unless err?
    ret = null
    await fs.open filename, flags, mode, defer err, fd
  unless err?
    await fs.realpath filename, defer err, realpath
    if err?
      log.warn "Realpath failed on file #{filename}: #{err}"
  unless err?
    opts = { fd, bufferSize }
    f = if write then fs.createWriteStream else fs.createReadStream
    stream = f filename, opts

  file = if err? then null
  else new File { stream , stat, realpath, filename, fd }

  cb err, file

##======================================================================

exports.stdout = () -> {
  stream : process.stdout
  filename : "<stdout>"
  realpath : "<stdout>"
  fd : -1
}

##======================================================================

