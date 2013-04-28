
stream = require 'stream'


class Trickler extends stream.Readable

  constructor : ->
    super()
    @i = 0

  _read : (sz) ->
    await setTimeout defer(), 500
    if @i >= 29
      @emit 'end'
    else
      @push new Buffer (@i for j in [0...23]) 
    @i++

class Batcher

  constructor : (@stream, @sz) ->
    @eof = false
    @error = null

    @stream.on 'readable', () =>
      @trigger()
    @stream.on 'end', () =>
      @eof = true
      @trigger()
    @stream.on 'close', () =>
      @eof = true
      @trigger()
    @stream.on 'error', (e) ->
      @error = e
      @eof = true
      @trigger()

  trigger : () ->
    if @_cb?
      t = @_cb
      @_cb = null
      t()

  read : (cb) ->
    ret = null
    eof = false

    while not ret and not eof and not @error?
      n = if @eof then null else @sz
      ret = @stream.read n

      if @eof and ret? and ret.length < @sz then eof = true
      else if not ret? and @eof then eof = true
      else if not ret? then await @_cb = defer()

    cb @error, eof, ret
      
t = new Trickler()
b = new Batcher t, 41

eof = false
while not eof
  await b.read defer err, eof, buf
  console.log buf

