
crypto = require 'crypto'
purepack = require 'purepack'
log = require './log'
{constants} = require './constants'
stream = require 'stream'
{Queue} = require './queue'

#==================================================================

pack2 = (o) ->
  b1 = purepack.pack o, 'buffer'
  b0 = purepack.pack b1.length, 'buffer'
  Buffer.concat [ b0, b1 ]

#==================================================================

# pad datasz bytes to be a multiple of blocksz
pkcs7_padding = (datasz, blocksz) ->
  plen = blocksz - (datasz % blocksz)
  new Buffer (plen for i in plen)

#==================================================================

bufeq : (b1, b2) ->
  return false unless b1.length is b2.length
  for b, i in b1
    return false unless b is b2[i]
  return true

#==================================================================

secure_bufeq = (b1, b2) ->
  ret = true
  if b1.length isnt b2.length
    ret = false
  else
    for b, i in b1
      ret = false unless b is b2[i]
  return ret

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

  ciphers : () -> [ "aes-256-cbc", "camellia-256-cbc" ]

  pad : (buf) ->
    padding = pkcs7_padding buf.length, @ENC_BLOCK_SIZE
    Buffer.concat [ buf, padding ]

  produce_keys : (bytes) ->
    eks = @ENC_KEY_SIZE
    mks = @MAC_KEY_SIZE
    parts = keysplit bytes, [ eks, eks, mks ]
    ret = {
      aes      : parts[0]
      camellia : parts[1]
      hmac     : parts[2]
    }
    ret

#==================================================================

gaf = new AlgoFactory()

#==================================================================

class Preamble

  @pack : () ->
    C = constants.Preamble
    i = new Buffer 4
    i.writeUInt32BE C.FILE_VERSION, 0
    Buffer.concat [ new Buffer(C.FILE_MAGIC), i ]

  @unpack : (b) -> bufeq Preamble.pack(), b
  
  @len : () -> 12

#==================================================================

msgpack_packed_numlen : (byt) ->
  if      byt < 0x80  then 1
  else if byt is 0xcc then 2
  else if byt is 0xcd then 3
  else if byt is 0xce then 5
  else if byt is 0xcf then 9
  else 0

#==================================================================

keysplit = (key, splits) ->
  ret = []
  start = 0
  for s in splits
    end = start + s
    ret.push key[start...end]
    start = end
  ret.push key[start...]
  ret

#==================================================================

class Transform extends stream.Transform

  #---------------------------

  constructor : (pipe_opts) ->
    super pipe_opts
    @_blocks = []

  #---------------------------

  _enable_ciphers   : -> @_cipher_fn = (block) => @_update_ciphers block
  _disable_ciphers  : -> @_cipher_fn = (block) => block

  #---------------------------

  _disable_streaming : ->  
    @_blocks = []
    @_sink_fn = (block) -> @_blocks.push block

  #---------------------------

  _enable_streaming  : -> 
    buf = Buffer.concat @_blocks
    @_blocks = []
    @push buf
    @_sink_fn = (block) -> @push block

  #---------------------------

  _send_to_sink : (block, cb) ->
    @_sink_fn @_process block
    cb() if cb?

  #---------------------------

  _process : (chunk)  -> @_mac @_cipher_fn chunk

  #---------------------------

  _prepare_macs : () ->
    # One mac for the header, and another for the whole file (including
    # the header MAC)
    @macs = (crypto.createHmac('sha256', @keys.hmac) for i in [0...2])

  #---------------------------

  _mac : (block) ->
    for m in @macs
      m.update block
    block

  #---------------------------

  _prepare_ciphers : (enc = true) ->
    ciphers = gaf.ciphers()
    @edatasize = @packed_stat.length + @stat.size
    nblocksz = @edatasize / gaf.ENC_BLOCK_SIZE
    @ivs = (crypto.rng(gaf.ENC_BLOCK_SIZE) for i in ciphers)

    prev = null

    @ciphers = for c, i in ciphers
      key = @keys[c.split("-")[0]]
      iv = @ivs[i]
      fn = if enc then crypto.createCipheriv else crypto.createDecipheriv
      fn c, key, iv

    # decrypt in the opposite order
    @ciphers.reverse() unless enc

  #---------------------------

  # Called before init_stream() to key our ciphers and MACs.
  setup_keys : (make_key, cb) ->
    tks = gaf.total_key_size()
    await @pwmgr.derive_key_material tks, make_key, defer km
    if km
      @keys = gaf.produce_keys km
      ok = true
    else ok = false
    cb ok

  #---------------------------

  # Chain the ciphers together, without any additional buffering from
  # pipes.  We're going to simplify this alot...
  _update_ciphers : (chunk) ->
    for c in @ciphers
      chunk = c.update chunk
    chunk

  #---------------------------
  # Cascading final update, the final from one cipher needs to be
  # run through all of the downstream ciphers...
  _final : () ->
    bufs = for c,i in @ciphers
      chunk = c.final()
      for d in @ciphers[(i+1)...]
        chunk = d.update chunk
      chunk
    Buffer.concat bufs

#==================================================================

exports.Encryptor = class Encryptor extends Transform

  constructor : ({@stat, @pwmgr}, pipe_opts) ->
    super pipe_opts
    @packed_stat = pack2 @stat, 'buffer'
    @_disable_ciphers()
    @_disable_streaming()

  #---------------------------


  _flush_ciphers : () -> @_sink_fn @_mac @_final()

  #---------------------------

  _write_preamble : () -> @_send_to_sink Preamble.pack()
  _write_pack     : (d) -> @_send_to_sink pack2 d
  _write_header   : () -> @_write_pack @_make_header()
  _write_mac      : () -> @_write_pack @macs.pop().digest()
  _write_metadata : () -> @_send_to_sink @packed_stat

  #---------------------------

  _make_header : () ->
    out = 
      version : constants.VERSION
      ivs : @ivs
      statsize : @packed_stat.length
      filesize : @stat.size
    return out

  #---------------------------

  _flush : (cb) ->
    @_flush_ciphers()
    @_disable_ciphers()
    @_write_mac()
    cb()

  #---------------------------

  init_stream : () ->

    @_prepare_ciphers()
    @_prepare_macs()

    @_write_preamble()
    @_write_header()
    @_write_mac()

    # Finally, we're starting to encrypt...
    @_enable_ciphers()
    @_write_metadata()

    # Now, we're all set, and subsequent operations are going
    # to stream to the output....
    @_enable_streaming()

  #---------------------------

  _transform : (block, encoding, cb) -> 
    @_send_to_sink block, cb

  #---------------------------

  init : (cb) ->
    await @setup_keys true, defer ok
    @init_stream() if ok
    cb ok

#==================================================================

[HEADER, BODY, FOOTER] = [0..2]

#==================================================================

exports.Decryptor = class Decryptor extends Transform

  constructor : (pipe_opts) ->
    super pipe_opts
    @_section = HEADER
    @_n = 0  # number of body bytes reads
    @_q = new Queue

  #---------------------------

  _enable_clear_queuing : ->
    @_enqueue = (block) => @_q.push block
    @_dequeue = (n, cb) => 
      await @_q.read n, defer b
      @_mac b if b?
      cb b

  #---------------------------

  _enable_deciphered_queueing : ->
    @_enqueue = (block) ->
      if block?
        @_mac block
        @_q.push @_update_ciphers block
    @_dequeue = (n, cb) => @_q.read n, cb

  #---------------------------

  _disable_queueing : ->
    @_enqueue = null
    @_dequeue = null

  #---------------------------

  _read_preamble : (cb) ->
    await @_dequeue Premable.len(), defer b
    ok = Preamble.unpack b 
    log.error "Failed to unpack preamble: #{b.inspect()}" unless ok
    cb ok

  #---------------------------

  _read_unpack : (cb) ->
    await @_dequeue 1, defer b
    framelen = msgpack_packed_numlen b
    if framelen is 0
      log.error "Bad msgpack len header: #{b.inspect()}"
    else
      await @_dequeue framelen, defer b
      [err, frame] = purepack.unpack b 
      if err?
        log.error "In reading msgpack frame: #{err}"
      else if not (typeof(frame) is number)
        log.error "Expected frame as a number: got #{frame}"
      else if not 
        await @_dequeue frame, defer b
        [err, out] = purepack.unpack b
        log.error "In unpacking #{b.inspect()}: #{err}" if err?
    cb out

  #---------------------------

  _read_header : (cb) ->
    ok = false
    await @_read_unpack defer @hdr
    if not @hdr?
      log.error "Failed to read header"
    else if @hdr.version isnt constants.VERSION
      log.error "Only know version #{constants.VERSION}; got #{@hdr.version}"
    else if not (@ivs = @hdr.ivs)? or not (@ivs.length is 2)
      log.error "Malformed headers; didn't find two IVs"
    else
      ok = true
    cb ok

  #---------------------------

  _check_mac : (cb) ->
    wanted = @macs.pop().digest()
    await @_read_unpack defer given
    ok = false
    if not given?
      log.error "Couldn't read MAC from file"
    else if not secure_bufeq given, wanted
      log.error "Header MAC mismatch error"
    else
      ok = true
    cb ok

  #---------------------------

  _enable_queued_ciphertext : () => 
    buf = @_q.flush()
    @_enable_deciphered_queueing()
    @_enqeue buf

  #---------------------------

  init_stream : (cb) ->
    ok = true

    @_prepare_macs()
    @_prepare_ciphers false

    await @_read_preamble defer ok
    await @_read_header   defer ok if ok
    await @_check_mac     defer ok if ok

    @_enable_queued_ciphertext()   if ok
    await @_read_metadata defer ok if ok 

    @_start_body()                 if ok
    cb ok

  #---------------------------

  _flush : (cb)->
    @_final()
    # XXX TODO we need to check the MAC
    cb()

  #---------------------------

  _stream_body : (block, cb) ->
    @push bl if (bl = @_update_ciphers @_mac block)?
    cb()

  #---------------------------

  _start_body : () ->
    @_section = BODY
    @push @_q.flush()
    @_disable_queueing()

  #---------------------------

  _read_metadata : (cb) ->
    await @_read_unpack defer obj
    cb ok

  #---------------------------

  _start_footer : (block) ->
    @_section = FOOTER
    @_enable_clear_queuing()
    @_enqeue block

  #---------------------------

  _handle_body : (block, cb) ->

    bl = block.length
    tot = @hdr.filesize
    b_rem = null

    if (diff = bl + @_n - tot) > 0
      tmp = block[0...diff]
      b_rem = block[diff...]
      block = tmp

    @_n += block.length
    await @_stream_body block, defer()
    @_start_footer b_rem if diff >= 0
    cb()

  #---------------------------

  _transform : (block, encoding, cb) ->
    if @_enqueue? then @_enqueue block
    else await @_handle_body block, defer()
    cb()

#==================================================================
