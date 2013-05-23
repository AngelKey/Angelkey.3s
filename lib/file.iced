
fs = require 'fs'
blockcrypt  = require './blockcrypt'
log = require './log'
{constants,error,status} = require './constants'
base58 = require './base58'
crypto = require 'crypto'
C = require 'constants'
{make_esc} = require './err'

#==================================================================

msgpack_packed_numlen = (byt) ->
  if      byt < 0x80  then 1
  else if byt is 0xcc then 2
  else if byt is 0xcd then 3
  else if byt is 0xce then 5
  else if byt is 0xcf then 9
  else 0

##======================================================================

exports.tmp_filename = tmp_filename = (stem) ->
  ext = base58.encode crypto.rng 8
  [stem, ext].join '.'

##======================================================================

exports.Basefile = class Basefile

  #------------------------

  constructor : ({@fd}) ->
    @fd = -1 unless @fd?
    @i = 0

  #------------------------

  offset : () -> @i

  #------------------------

  close : () ->
    if @fd? >= 0
      fs.close @fd
      @fd = -1
      @i = 0

##======================================================================

exports.Stdout = class Stdout extends Basefile

  constructor : () ->
    @filename = "<stdout>"
    @pos = 0
    @stream = process.stdout

  _open : (cb) -> cb null

  @open : ({}, cb) ->
    file = new Stdout()
    cb err, file

  finish : (ok, cb) ->
    await @stream.end defer err
    cb err

  write : (block, cb) ->
    if block.offset isnt @pos
      err = new Error "Can't seek stdout"
    else
      await @stream.write block.buf, null, defer err
      @pos += block.buf.length
    cb err

##======================================================================

exports.Outfile = class Outfile extends Basefile

  #------------------------

  constructor : ({@target, @mode}) ->
    super({})
    @mode = 0o644 unless @mode?
    @tmpname = tmp_filename @target
    @renamed = false
    @buf = null
    @i = 0

  #------------------------

  @open : ({target, mode}, cb) ->
    file = if target? then new Outfile { target, mode }
    else new Stdout {}
    await file._open defer err
    file = null if err?
    cb err, file

  #------------------------

  _open : (cb) ->
    esc = make_esc cb, "Open #{@target} for writing"
    flags = (C.O_WRONLY | C.O_TRUNC | C.O_EXCL | C.O_CREAT)
    await fs.open @tmpname, flags, @mode, esc defer @fd
    await fs.realpath @tmpname, esc defer @realpath
    cb null

  #------------------------

  _rename : (cb) ->
    await fs.rename @tmpname, @target, defer err
    if err?
      log.error "Failed to rename temporary file: #{err}"
    else
      @renamed = true
    cb not err?

  #------------------------

  finish : (success, cb) ->
    @close()
    await @_rename defer() if @success
    await @_cleanup defer()
    cb()

  #------------------------

  _cleanup : (cb) ->
    ok = false
    if not @renamed
      await fs.unlink @tmpname, defer err
      if err?
        log.error "failed to remove temporary file: #{err}"
        ok = false
    cb ok

  #------------------------

  write : (block, cb) ->
    ok = false
    l = block.buf.length
    b = block.buf
    o = block.offset
    await fs.write @fd, b, 0, l, o, defer err, nw
    if err?
      err = new Error "In writing #{@tmpname}@#{o}: #{err}"
    else if nw isnt l 
      err = new Error "Short write in #{@tmpname}: #{nw} != #{l}"
    cb err

##======================================================================

exports.Block = class Block

  constructor : ({@buf, @offset}) ->

  encrypt : (eng) -> [null, new Block { buf : eng.encrypt(@buf), @offset } ]

  decrypt : (eng) ->
    [rc, buf] = eng.decrypt @buf
    out = null
    err = null
    if rc is sc.OK and buf?
      out = new Block { buf, @offset }
    else
      err = new Error "decryption err: #{error.to_string rc}"
    [ err , out ]

##======================================================================

exports.Infile = class Infile extends Basefile

  constructor : ({@stat, @realpath, @filename, @fd}) ->
    super { @fd }
    @buf = null
    @eof = false

  #------------------------

  size : () -> 
    throw new Error "file is not opened" unless @stat
    @stat.size

  #------------------------

  read : (offset, n, cb) ->
    ret = null
    @buf = new Buffer size unless @buf and @buf.length is size
    await fs.read @fd, @buf, 0, n, offset, defer err, br
    if err? 
      err = new Error "#{@filename}/#{offset}-#{offset+n}: #{err}"
    else if br isnt n 
      err = new Error "Short read: #{br} != #{n}"
    else
      ret = new Block { @buf, offset }
    cb err, ret

  #------------------------

  next : (n, cb) ->
    await @read @i, n, defer err, block
    if block?
      @i += buf.length
      @eof = @i >= @stat.length
    else
      @eof = true
    cb err, block, eof

  #------------------------

  @open : (filename, cb) ->
    file = new Infile {filename}
    await file._open defer err
    file = null if err?
    cb err, file

  #------------------------

  finish : (ok, cb) ->
    @close()
    cb null

  #------------------------

  _open : (cb) ->
    esc = make_esc cb, "Open #{@filename}"
    flags = C.O_RDONLY
    await fs.open @filename, flags, esc defer @fd
    await fs.fstat @fd, esc defer @stat
    await fs.realpath @filename, esc defer @realpath
    cb null

#==================================================================

concat = (lst) -> Buffer.concat lst

#==================================================================

pack2 = (o) ->
  b1 = purepack.pack o, 'buffer', { byte_arrays : true }
  b0 = purepack.pack b1.length, 'buffer'
  concat [ b0, b1 ]

##======================================================================

unpack2 = (rfn, cb) ->
  esc = make_esc cb, "unpack"
  out = null
  err = null

  await rfn 1, esc defer b0
  framelen = msgpack_packed_numlen b0.bufer[0]

  if framelen is 0
    err = new Error "Bad msgpack len header: #{b.inspect()}"
  else

    if framelen > 1
      # Read the rest out...
      await rfn (framelen-1), esc defer b1
      b = concat [b0, b1]
    else
      b = b0

    # We've read the framing in two parts -- the first byte
    # and then the rest
    [err, frame] = purepack.unpack b

    if err?
      err = new Error "In reading msgpack frame: #{err}"
    else if not (typeof(frame) is 'number')
      err = new Error "Expected frame as a number: got #{frame}"
    else 
      await rfn frame, defer b
      [err, out] = purepack.unpack b
      err = new Error "In unpacking #{b.inspect()}: #{err}" if err?

  cb err, out

##======================================================================

unpack2_from_buffer = (buf, cb) ->
  rfn = (n, cb) ->
    if n > buf.length then err = new Error "read out of bounds"
    else 
      ret = buf[0...n]
      buf = buf[n...]
    cb err, res
  await unpack2 rfn, defer err, buf
  cb err, but

##======================================================================

uint32 = (i) ->
  b = new Buffer 4
  b.writeUInt32BE i
  b

##======================================================================

class CoderBase

  #--------------

  constructor : ({@keys, @infile, @outfile, @blocksize}) ->
    @blocksize = 1024*1024 unless @blocksize?
    @eof = false
    @opos = 0

  #-------------------------

  more_to_go : () -> not @eof

  #--------------

  @premable : () ->
    H = constants.Header
    concat [
      H.FILE_MAGIC
      uint32 H.FILE_VERSION
    ]

  #--------------

  run : (cb) ->
    esc = make_esc cb, "CoderBase::run"
    await @first_block esc defer()
    bs = @sizer @blocksize
    while @more_to_go()
      await @read bs, esc defer block
      if block?
        block.offset = @opos
        await @write block, esc defer()
        @opos += block.buf.length
    cb null

  #--------------

  write : (buf, cb) -> 
    await @outfile.write buf, defer err
    if err?
      log.error err
    cb err

 #--------------

  read : (i, cb) ->
    await @input.next i, defer err, iblock, @eof
    if err?
      log.error err
    else if @oblock?
      [err, oblock] = @filt iblock 
    cb err, oblock

##======================================================================

exports.Decoder = class Decoder extends CoderBase

  #--------------

  constructor : (d) ->
    super d

  #---------------------------

  _read_premable : (cb) ->
    p = CoderBase.preamble()
    await @infile.next p.length, defer err, raw

    err = if err? then err
    else if not bufeq raw.buf, p then new Error "Premable mismatch/bad magic"
    else null
    cb err

  #---------------------------

  _read_unpack : (cb) ->
    rfn = (i, cb) => @input.next i, cb
    await unpack2 rfn, defer err, obj
    cb err, obj

  #---------------------------

  _read_metadata : (cb) ->
    await @_read_unpack esc defer @hdr
    fields = [ "statsize", "filesize", "encrypt", "blocksize" ]
    f = []
    for f in fields 
      missing.push f if not @hdr[f]?
    err = new Error "malformed header; missing #{JSON.stringify f}" if f.length
    cb err

  #---------------------------

  _read_encrypted_stat : (cb) ->
    await @infile.next @hdr.statsize, defer err, raw
    [err, block] = @filt raw unless err?
    [err, @stat] = unpack2_from_buffer block unless err?
    cb err

  #---------------------------

  _read_header : (cb) ->
    esc = make_esc cb, "Decoder::_read_header"
    await @_read_premable esc defer()
    await @_read_metadata esc defer()
    await @_read_encrypted_stat esc defer()
    cb null

  #--------------

  _read_first_block : (cb) ->
    @blocksize = @hdr.blocksize
    rem_off = @infile.offset()
    err = null
    if rem_off > @blocksize 
      err = new Error "header was too big! #{rem_off} > #{@blocksize}"
    else
      rem_size = @blocksize - rem_off
      await @infile.next rem_size, defer err, block
      [err, block] = @filt block unless err?
      block.offset = 0
      await @write block, defer err
      @opos = block.length
    cb err

  #--------------

  first_block : (cb) ->
    await @_read_header defer err
    await @_read_first_block defer err unless err?
    cb err

##======================================================================

exports.Encoder = class Encoder extends CoderBase

  #--------------

  constructor : (d) ->
    super d

  #--------------
  
  metadata : (statsize, filesize) ->
    encrypt = @encflag()
    pack2 { statsize, filesize, encrypt, @blocksize }

  #--------------
  
  header : () ->
    [_, estat ] = @filt pack2 @infile.stat
    concat [
      CoderBase.premable()
      @metadata estat.length, @infile.stat.size
      estat
    ]

  #--------------
  
  first_block : (cb) ->
    err = null
    hdr = @header()
    if hdr.length > @blocksize
      err = new Error "First block is too big!! #{hdr.length} > #{@blocksize}"
      log.error err
    else
      rem_osize = @blocksize - hdr.length
      rem_isize = @sizer rem_osize
      await @read rem_isize, defer err, rem_block
    unless err?
      buf = concat [ hdr, rem_block.buf ]
      block = new Block { buf, offset : 0 }
      await @write block, defer err
      @opos = @block.length
    cb err

##======================================================================

exports.PlainEncoder = class PlainEncoder extends Encoder

  constructor : ({@infile, @outfile, @blocksize}) ->
    super()

  filt : (x) -> [ null, x ]
  sizer : (x) -> x
  encflag : -> 0

##======================================================================

exports.Encryptor = class Encryptor extends Encoder

  constructor : ({@keys, @infile, @outfile, @blocksize}) ->
    super()
    @block_engine = new blockcrypt.Engine @keys

  filt : (x) -> x.encrypt @block_engine
  sizer  : (x) -> blockcrypt.Engine.input_size x
  encflag : -> 1

##======================================================================

exports.Decryptor = class Decryptor extends Decoder

  constructor : ({@keys, @infile, @outfile}) ->
    super()
    @block_engine = new blockcrypt.Engine @keys

  filt   : (x) -> x.decrypt @block_engine
  sizer  : (x) -> x

##======================================================================

exports.PlainDecoder = class Decryptor extends Decoder

  constructor : ({infile, @outfile}) ->
    super()
  filt   : (x) -> [ null, x ]
  sizer  : (x) -> x

##======================================================================
