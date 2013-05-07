
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
 
  subcommand : ->
    help : 'decrypt a file'
    name : 'decrypt'
    aliases : [ 'dec' ]
    epilog : 'Act like a unix filter and decrypt a local file'

#=========================================================================
