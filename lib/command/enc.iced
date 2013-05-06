
{CipherBase} = require './base'
mycrypto = require '../crypto'

#=========================================================================

exports.Command = class Command extends CipherBase
  output_filename : () ->
    @argv.o or [ @infn, @file_extension() ].join '.'
  make_eng : (args...) -> new mycrypto.Encryptor args...

  subcommand : ->
    help : 'encrypt a file'
    name :  'encrypt'
    aliases : [ 'enc' ]
    epilog : "Act like a unix filter and just encrypt a file to local storage"

#=========================================================================

