#!/usr/bin/env iced

{CipherBase} = require './base'
mycrypto = require '../crypto'

#=========================================================================

exports.Command = class Command extends cmd.CipherBase
   
  #-----------------

  output_filename : () ->
    if not @argv.o? then @strip_extension @infn
    else if @argv.o isnt '-' then @argv.o
    else null

  #-----------------
 
  make_eng : (args...) -> new mycrypto.Decryptor args...
  
  #-----------------
 
  short_description : -> "encrypt a local file"

#=========================================================================
