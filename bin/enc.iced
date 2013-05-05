#!/usr/bin/env iced

cmd = require '../lib/command'
log = require '../lib/log'
fs   = require 'fs'
myfs = require '../lib/fs'
crypto = require 'crypto'
mycrypto = require '../lib/crypto'
base58 = require '../lib/base58'

#=========================================================================

class Command extends cmd.CipherBase

  #-----------------

  output_filename : () ->
    @argv.o or [ @infn, @file_extension() ].join ''

  #-----------------

  eng_class : () -> mycrypto.Encryptor

#=========================================================================

cmd = new Command()
await cmd.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

