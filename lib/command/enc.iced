
{CipherBase} = require './base'
mycrypto = require '../crypto'

#=========================================================================

exports.Command = class Command extends CipherBase

  #-----------------

  output_filename : () ->
    @argv.output or [ @infn, @file_extension() ].join '.'

  #-----------------

  make_eng : (args...) -> new mycrypto.Encryptor args...
  
  #-----------------
 
  subcommand : ->
    help : 'encrypt a file'
    name : 'enc'
    aliases : [ 'encrypt' ]
    epilog : 'Act like a unix filter and encrypt a local file'


#=========================================================================

