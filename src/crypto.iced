
crypto = require 'crypto'

#==================================================================

class Factory 

  constructor : ->
    # Keysize in bytes for AES256 and Blowfish
    @ENC_KEY_SIZE = 16
    # Use the same keysize for our MAC too
    @MAC_KEY_SIZE = 16

  total_key_size : () ->
    2 * @ENC_KEY_SIZE + @MAC_KEY_SIZE

  produce_keys : (bytes) ->
    eks = @ENC_KEY_SIZE
    return {
      aes : bytes[0...eks]
      bf  : bytes[eks...(2*eks)]
      mac : bytes[(2*eks)...]
    }

#==================================================================

class Engine