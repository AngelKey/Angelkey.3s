#!/usr/bin/env iced

cmd = require '../lib/command'
mycrypto = require '../lib/crypto'

#=========================================================================

class Command extends cmd.CipherBase

  #-----------------

  output_filename : () ->
    @argv.o or [ @infn, @file_extension() ].join '.'

  #-----------------

  make_eng : (args...) -> new mycrypto.Encryptor args...

#=========================================================================

cmd = new Command()
await cmd.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

