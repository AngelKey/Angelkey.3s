#
# blockcrypt.iced --- The crypto engine for working on a 1MB block of data.
#
#  Earlier versions of crypto in mkb used streaming crypto, and two
#  different algorithms for encryption.  I think those were both mistakes.
#  Streaming crypto doesn't work well with the block-based multipart
#  API that amazon exposes in glacier.  It's esepcially inconvenient
#  when it comes to interrupted transfers.
#
#  So why just one cipher?  I was worried I couldn't find a second
#  cipher in OpenSSL 1.0.1d that will be around in 10 years. The only
#  candidate is Camellia, but I'm concerned that no one seems to 
#  use it, and there might not be a ready implementation available
#  when you need to actually access the backup. So the compromise
#  is to use the most obvious algorithm: AES-256-CBC.  It's a small
#  trade-off security-wise, but the case for encryption here isn't
#  overwhelming.  It seems way more likely that Camellia will become
#  unsupported than someone will (a) want to break into your files and
#  (b) be able to break AES-256.
#
#==================================================================

crypto = require 'crypto'
{status} = require './constants'

#==================================================================

exports.bufeq = bufeq = (b1, b2) ->
  return false unless b1.length is b2.length
  for b, i in b1
    return false unless b is b2[i]
  return true

#==================================================================

exports.secure_bufeq = secure_bufeq = (b1, b2) ->
  ret = true
  if b1.length isnt b2.length
    ret = false
  else
    for b, i in b1
      ret = false unless b is b2[i]
  return ret

#==================================================================

exports.bufsplit = bufsplit = (key, splits) ->
  ret = []
  start = 0
  for s in splits
    end = start + s
    ret.push key[start...end]
    start = end
  ret.push key[start...]
  ret

#==================================================================

exports.Algos = class Algos

  # Encode AES-256-CBC for encryption and HMAC-SHA-256 for
  # hmac
  @S = 
    enc :
      block : 16
      key : 32
    hmac :
      key : 32
      out : 32

  #--------------------

  @enc : (key) ->
    iv = crypto.rng Algos.S.enc.block
    cipher = crypto.createCipheriv 'aes-256-cbc', key, iv
    { iv, cipher }

  #--------------------

  @dec : (key, iv) -> crypto.createDecipheriv 'aes-256-cbc', key, iv
  @mac : (key) -> crypto.createHmac 'sha256', key

  #--------------------

  @iv_size : () -> Algos.S.enc.block
  @mac_size : () -> Algos.S.hmac.out

  # The minimum pad size with CBC! Somewhat of a hack, but eh!
  @pad_size : () -> 1

  #--------------------

#==================================================================

exports.Keys = class Keys

  @raw_length : () -> Algos.S.enc.key + Algos.S.hmac.key

  #--------------------

  constructor : (km) ->
    [@enc, @mac] = bufsplit km, [ Algos.S.enc.key, Algos.S.hmac.key ]

#==================================================================

exports.Engine = class Engine 
  constructor : (@keys) ->

  #--------------------

  @header_size : () -> Algos.iv_size()
  @footer_size : () -> Algos.mac_size()
  @metadata_size : () -> Engine.header_size() + Engine.footer_size() + Algos.pad_size()

  #--------------------

  # The most possible input size you can squeeze into this output_size.
  # Note, we make use of our knowledge of CBC padding here -- the cheapest
  # block size is one that is 15 mod 16, and in that case, we only need 1 
  # pad byte.
  @input_size : (output_size) -> output_size - Engine.metadata_size()

  #--------------------

  encrypt : (inblock) ->
    { iv, cipher } = Algos.enc @keys.enc
    mac = Algos.mac @keys.mac
    blocks = [
      iv,
      cipher.update inblock
      cipher.final()
    ]
    (mac.update b for b in blocks)
    blocks.push mac.digest()
    Buffer.concat blocks

  #--------------------

  decrypt : (inblock) ->
    rc = status.OK
    block = null

    if inblock.length < Engine.metadata_size() then rc = status.E_BAD_SIZE
    else
      bodlen = inblock.length - Engine.header_size() - Engine.footer_size()
      splits = [ Engine.header_size(), bodlen ]
      [iv,body,given_mac] = bufsplit inblock, splits

      macer = Algos.mac @keys.mac
      macer.update iv
      macer.update body
      computed_mac = macer.digest()

      if not secure_bufeq computed_mac, given_mac
        rc = status.E_BAD_MAC
      else
        dec = Algos.dec @keys.enc, iv
        block = Buffer.concat [ dec.update(body), dec.final() ]
    [rc, block]

#==================================================================
