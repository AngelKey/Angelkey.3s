
crypto = require 'crypto'
purepack = require 'purepack'

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

  next : () ->
    start = 0
    if @bytes > 4
      @numbuf.writeUInt32BE Math.floor(@i/UINT32_MAX), 0
      @numbuf.writeUInt32BE (@i % UINT32_MAX), 4    
      console.log @numbuf
    else 
      @numbuf.writeUInt32BE @i, 0
    @numbuf.copy @block, (gaf.ENC_BLOCK_SIZE - @bytes), (@numbuflen - @bytes), @numbuflen
    @i++
    @block

#==================================================================

class Encryptor 

  constructor : ({@env, @sin, @sout, @stat}) ->
    @packed_stat = purepack.pack @stat, 'buffer'

  #---------------------------

  _prepare_password : (cb) ->
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
    @edsize = @packed_stat.length + @stat.size
    nblocksz = @edsize / gaf.ENC_BLOCK_SIZE

    @ciphers = (crypto.createCipher(c, @keys[c]) for c in ciphers)
    @ivs = (new CtrIv(nblocksz) for c in ciphers)
    cb true

  #---------------------------

  run : (cb) ->
    await @_prepare_password defer ok if ok
    await @_prepare_ciphers  defer ok if ok 
    await @_prepare_macs     defer ok if ok
    await @_write_header     defer ok if ok
    await @_write_mac        defer ok if ok
    await @_write_body       defer ok if ok
    await @_write_mac        defer ok if ok
    cb ok

#==================================================================


civ = new CtrIv 12900000000000
for i in [0...200]
  console.log civ.next()






