#!/usr/bin/env iced

cmd = require '../lib/command'
log = require '../lib/log'
fs   = require 'fs'
crypto = require 'crypto'
mycrypto = require '../lib/crypto'
myfs = require '../lib/fs'

#=========================================================================

class Command extends cmd.CipherBase
   
  #-----------------

  constructor : () ->
    super()

  #-----------------

  output_filename : () ->
    if not @argv.o? then @strip_extension @infn
    else if @argv.o isnt '-' then @argv.o
    else null

  #-----------------

  run : (cb) ->
    await @init defer ok

    if ok
      enc = new mycrypto.Decryptor { @pwmgr }
      await enc.init defer ok
      if not ok
        log.error "Could not setup encryption keys"
    if ok
      istream.pipe(enc).pipe(ostream)
      await istream.once 'end', defer()
      await ostream.once 'finish', defer()

    await @cleanup ok, defer()
    cb ok

#=========================================================================

cmd = new Command()
await cmd.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

