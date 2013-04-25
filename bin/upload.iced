#!/usr/bin/env iced

path = require 'path'
fs = require 'fs'
AWS = require 'aws-sdk'
argv = require('optimist').alias("v", "vault").argv

warn = (x) -> console.log x

load_config = (cb) ->
  config = path.join process.env.HOME, ".mkbkp.json"
  await fs.exists config, defer exists
  AWS.config.loadFromPath config if exists
  cb()

await load_config defer()

#=========================================================================

class Uploader

  #--------------

  constructor : (@filename) ->
    @leaf_hashes = []
    @chunksz = 1024 * 1024
    @buf = new Buffer @chunksz
    @pos = 0
    @eof = false
    @err = true
    @glacier = new AWS.Glacier()

  #--------------

  can_read : -> not @eof and not @err

  #--------------

  read_chunk : (cb) ->
    i = 0
    while @can_read() and i < @chunksz
      left = @chunksz - i
      await fs.read @fd, @buf, i, left, @pos, defer err, nbytes, buf
      if err
        warn "In reading #{@filename}@#{@pos}: #{err}"
        @err = true
      else if buf is null
        @eof = true
      else
        i += nbytes
        @pos += nbytes

    ret = if i < @chunksz then @buf[0...i]
    else if @err then null
    else @buf

    cb ret

  #--------------

  open : (cb) ->
    await fs.open @filename, "r", defer err, @fd
    if err?
      warn "In opening file #{@filename}: #{err}"
      ok = false
    else
      @pos = 0
      @eof = false
      ok = true
    cb ok

  #--------------

  hash : (cb) ->
    full = aws.util.crypto.createHash 'sha256'
    leafs = []
    while @can_read()
      await @read_chunk defer chnk
      full.update chnk
      leafs.push AWS.util.crypto.sha256 chunk

#=========================================================================




