
fs = require 'fs'
blockcrypt  = require './blockcrypt'
log = require './log'

##======================================================================

exports.Infile = class Infile

  constructor : ({@stat, @realpath, @filename, @fd}) ->
    @fd = -1 unless @fd?

  #------------------------

  close : () ->
    if @fd? >= 0
      fs.close @fd
      @fd = -1

  #------------------------

  size : () -> 
    throw new Error "file is not opened" unless @stat
    @stat.size

  #------------------------

  open : (cb) ->

    err = null

    unless err?
      await fs.open @filename, flags, defer err, @fd
      if err?
        log.warn "Open failed on #{@filename}: #{err}"

    unless err?
      await fs.fstat @fd, defer err, @stat
      if err?
        log.warn "failed to access file #{@filename}: #{err}"

    unless err?
      await file.realpath defer err, @realpath
      if err?
        log.warn "Realpath failed on #{@filename}: #{err}"

    cb err

    #------------------------

##======================================================================
