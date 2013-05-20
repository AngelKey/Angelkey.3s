
fs = require 'fs'
blockcrypt  = require './blockcrypt'
log = require './log'
{constants} = require './constants'

##======================================================================

exports.Infile = class Infile

  constructor : ({@stat, @realpath, @filename, @fd}) ->
    @fd = -1 unless @fd?
    @buf = null
    @i = 0

  #------------------------

  close : () ->
    if @fd? >= 0
      fs.close @fd
      @fd = -1

  #------------------------

  size : () -> 
    throw new Error "file is not opened" unless @stat
    @stat.size

  #------------------------

  read : (offset, n, cb) ->
    @buf = new Buffer size unless @buf and @buf.length is size
    await fs.read @fd, @buf, 0, n, offset, defer err, br
    if err?
      log.error "Error reading #{@filename}/#{offset}-#{offset+n}: #{err}"
    else if br isnt n
      log.error "Short read: #{br} != #{n}"
    else
      ret = @buf
    cb @buf

  #------------------------

  next : (n, cb) ->
    await @read @i, n, defer buf
    if buf?
      @i += buf.length
      eof = @i >= @stat.length
    else
      eof = true
    cb buf, eof

  #------------------------

  open : (cb) ->

    err = null

    unless err?
      await fs.open @filename, flags, defer err, @fd
      if err?
        log.warn "Open failed on #{@filename}: #{err}"

    unless err?
      await fs.fstat @fd, defer err, @stat
      if err?
        log.warn "failed to access file #{@filename}: #{err}"

    unless err?
      await file.realpath defer err, @realpath
      if err?
        log.warn "Realpath failed on #{@filename}: #{err}"

    cb err

#==================================================================

concat = (lst) -> Buffer.concat lst

#==================================================================

pack2 = (o) ->
  b1 = purepack.pack o, 'buffer', { byte_arrays : true }
  b0 = purepack.pack b1.length, 'buffer'
  concat [ b0, b1 ]

##======================================================================

uint32 = (i) ->
  b = new Buffer 4
  b.writeUInt32BE i
  b

##======================================================================

exports.Outputter = class Outputter

  #--------------

  constructor : ({@keys, @infile, @outfile, @blocksz}) ->
    @eof = false
    @ok = false
    if @encrypt
    else
      @infilt = (x) -> x
      @sizer  = (x) -> x

  #--------------
  
  preamble : (statsize, filesize) ->
    H = constants.Header
    encrypt = @encflag()
    concat [
      H.FILE_MAGIC
      uint32 H.FILE_VERSION
      pack2 { statsize, filesize, encrypt }
    ]

  #--------------
  
  header : () ->
    estat = @infilt pack2 @infile.stat
    concat [
      @preamble estat.length, @infile.stat.size
      estat
    ]

  #--------------

  read : (i) ->
    await @input.next i, defer iblock, @eof
    oblock = @infilt iblock if oblock?
    cb oblock

  #--------------

  write : (buf) ->
    await @output.next buf, defer ok
    cb ok

  #--------------

  run : (cb) ->
    await @first_block defer ok
    bs = @sizer @blocksz
    while @ok and not @eof
      await @read bs, defer block
      await @write block, defer() if block?
    cb @ok

  #--------------
  
  first_block : (cb) ->
    hdr = @header()
    if hdr.length > @blocksz
      log.error "First block is too big!! #{hdr.length} > #{@blocksz}"
      @ok = false
    else
      rem_osize = @blocksz - hdr.length
      rem_isize = @sizer rem_osize
      await @read rem_isize, defer rem_block
    if @ok
      block = concat [ hdr, rem_block ]
      await @write block, defer()

    cb()

##======================================================================

exports.PlainOutputter = class PlainOutputter

  constructor : ({@keys, @infile, @outfile, @blocksz}) ->
    super()

  infilt : (x) -> x
  sizer : (x) -> x
  encflag : -> 0

##======================================================================

exports.Encryptor = class Encryptor 

  constructor : ({@keys, @infile, @outfile, @blocksz}) ->
    super()
    @block_engine = new blockcrypt.Engine @keys

  infilt : (x) -> @block_engine.encrypt x
  sizer  : (x) -> blockcrypt.Engine.input_size x
  encflag : -> 1

##======================================================================
