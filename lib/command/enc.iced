
cmd = require '../lib/command'
mycrypto = require '../lib/crypto'

#=========================================================================

class Command extends cmd.CipherBase

  #-----------------

  output_filename : () ->
    @argv.o or [ @infn, @file_extension() ].join '.'

  #-----------------

  make_eng : (args...) -> new mycrypto.Encryptor args...
  
  #-----------------
 
  subcommand : ->
    help : 'encrypt a file'
    name : 'encrypt'
    aliases : [ 'enc' ]
    epilog : 'Act like a unix filter and encrypt a local file'


#=========================================================================

