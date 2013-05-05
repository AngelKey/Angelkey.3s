#!/usr/bin/env iced

cmd = require '../lib/command'
mycrypto = require '../lib/crypto'

#=========================================================================

class Command extends cmd.CipherBase
   
  #-----------------

  output_filename : () ->
    if not @argv.o? then @strip_extension @infn
    else if @argv.o isnt '-' then @argv.o
    else null

  #-----------------

  make_eng : (args...) -> new mycrypto.Decryptor args...

#=========================================================================

cmd = new Command()
await cmd.run defer ok
process.exit if ok then 0 else -2

#=========================================================================

