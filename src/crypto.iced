
crypto = require 'crypto'
purepack = require 'purepack'
log = require './log'
{constants} = require './constants'

#==================================================================

pack2 = (o) ->
  b1 = purepack.pack o, 'buffer'
  b0 = purepack.pack b1.length, 'buffer'
  b0.concat b1

#==================================================================

# pad datasz bytes to be a multiple of blocksz
pkcs7_padding = (datasz, blocksz) ->
  plen = blocksz - (datasz % blocksz)
  new Buffer (plen for i in plen)

#==================================================================

class AlgoFactory 

  constructor : ->
    # Keysize in bytes for AES256 and Blowfish
    @ENC_KEY_SIZE = 32
    @ENC_BLOCK_SIZE = 16
    # Use the same keysize for our MAC too
    @MAC_KEY_SIZE = 32

  total_key_size : () ->
    2 * @ENC_KEY_SIZE + @MAC_KEY_SIZE

  ciphers : () -> [ "aes256", "blowfish" ]

  pad : (buf) ->
    padding = pkcs7_padding buf.length, @ENC_BLOCK_SIZE
    buf.concat padding

  produce_keys : (bytes) ->
    eks = @ENC_KEY_SIZE
    mks = @MAC_KEY_SIZE
    parts = keysplit bytes, [ eks, eks, mks ]
    return {
      aes256   : parts[0]
      blowfish : parts[1]
      hmac     : parts[2]
    }

#==================================================================

gaf = new AlgoFactory()

#==================================================================

class Preamble

  @FILE_VERSION = 1
  @FILE_MAGIC = new Buffer [ 0x88, 0xb4, 0x84, 0xb8, 0x58, 0x36, 0x39, 0x9f ]
  @LEN = 12

  @pack : () ->
    i = new Buffer 4
    i.writeUInt32BE Preamble.FILE_VERSION, 0
    Preamble.FILE_MAGIC.concat i

  @unpack : (b) ->
    known = Preamble.pack()
    return false unless known.length is b.length
    for c,i in known
      return false unless c is b[i]
    return true

#==================================================================

msgpack_packed_numlen : (byt) ->
  if      byt < 0x80  then 1
  else if byt is 0xcc then 2
  else if byt is 0xcd then 3
  else if byt is 0xce then 5
  else if byt is 0xcf then 9
  else 0

#==================================================================

keysplit = (keys, splits) ->
  ret = []
  start = 0
  for s in splits
    end = start + s
    ret.push key[start...end]
    start = end
  ret.push key[start...]
  ret

#==================================================================

log_base_256 = (n) -> 
  ret = 0
  while n > 0
    n = Math.floor(n / 256)
    ret++
  ret

#==================================================================

UINT32_MAX = Math.pow(2,32)

class CtrIv

  constructor : (@nblocks) ->  
    @i = 0
    @block = crypto.rng gaf.ENC_BLOCK_SIZE
    @bytes = log_base_256 @nblocks
    @numbuflen = if @bytes > 4 then 8 else 4
    @numbuf = new Buffer @numbuflen
    @start = @bytes 

  output : (adv = true) ->
    start = 0
    if @bytes > 4
      @numbuf.writeUInt32BE Math.floor(@i/UINT32_MAX), 0
      @numbuf.writeUInt32BE (@i % UINT32_MAX), 4    
      console.log @numbuf
    else 
      @numbuf.writeUInt32BE @i, 0
    @numbuf.copy @block, (gaf.ENC_BLOCK_SIZE - @bytes), (@numbuflen - @bytes), @numbuflen
    @i++ if adv
    @block

#==================================================================

class Encryptor 

  constructor : ({@env, @sin, @sout, @stat}) ->
    @packed_stat = gaf.pad(pack2(@stat, 'buffer'))

  #---------------------------

  _prepare_keys : (cb) ->
    tks = gaf.total_key_size()
    await @env.pwmgr.derive_key_material tks, defer km
    if km
      @keys = gaf.produce_keys km
      ok = true
    else
      ok = false
    cb ok

  #---------------------------

  _prepare_ciphers : (cb) ->
    ciphers = gaf.cipers()
    @edatasize = @packed_stat.length + @stat.size
    nblocksz = @edatasize / gaf.ENC_BLOCK_SIZE
    @ciphers = (crypto.createCipher(c, @keys[c]) for c in ciphers)
    @ivs = (new CtrIv(nblocksz) for c in ciphers)
    cb true

  #---------------------------

  _prepare_macs : (cb) ->
    @macs = (crypto.createHmac 'sha256', @keys.hmac)

  #---------------------------

  _write : (block, cb) ->
    await @sout.write block, defer err
    ok = true
    if err
      log.error "Error writing: #{err}"
      ok = false
    else
      for m in @macs
        m.update block
    cb ok

  #---------------------------

  _write_premable : (cb) ->
    b = Preamble.pack()
    await @_write b, defer ok
    cb ok

  #---------------------------

  _make_header : () ->
    out = 
      version : constants.VERSION
      ivs : (iv.output(false) for iv in @ivs)
      statsize : @packed_stat.length
      filesize : @stat.size
    return out

  #---------------------------

  _write_pack : (d,cb) ->
    await @_write(pack2(d)), defer ok
    cb ok

  #---------------------------

  _write_header : (cb) ->
    h = @_make_header()
    await @_write_pack h, defer ok
    cb ok

  #---------------------------

  _write_mac : (cb) ->
    m = @macs.pop()
    b = new Buffer b.digest(), 'binary'
    await @_write_pack b, defer ok
    cb ok

  #---------------------------

  # Assume chunks are aligned in 16-byte boundaries, or this is the last chunk
  _encrypt : (chunk) ->
    cl = chunk.length

    # A buffer to encrypt into
    buf = if @last?.length is cl then @last else new Buffer cl

    nc = Math.floor cl / gaf.ENC_BLOCK_SIZE

    p = 0
    for i in nc
      



  #---------------------------

  _write_body : (cb) ->
    await @_encrypt @packed_stat, defer ok
    while ok
      await @sin.read defer err, block
      if err
        log.error "Error reading from input: #{err}"
        ok = false
      else if not block?
        ok = false
      else 
        await @_encrypt block, defer ok
    await @_encrypt null, defer ok
    cb ok

  #---------------------------

  run : (cb) ->
    await @_prepare_keys    defer ok if ok
    await @_prepare_ciphers defer ok if ok 
    await @_prepare_macs    defer ok if ok
    await @_write_preamble  defer ok if ok
    await @_write_header    defer ok if ok
    await @_write_mac       defer ok if ok
    await @_write_body      defer ok if ok
    await @_write_mac       defer ok if ok
    cb ok

#==================================================================


civ = new CtrIv 12900000000000
for i in [0...200]
  console.log civ.next()






