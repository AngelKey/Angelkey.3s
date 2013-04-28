
stream = require 'stream'


class Trickler extends stream.Readable

  constructor : ->
    super()
    @i = 0

  _read : (sz) ->
    await setTimeout defer(), 100
    if @i >= 35
      @emit 'end'
    else
      @push new Buffer [@i]
    @i++

class Batcher

  constructor : (@stream, @sz) ->
    @eof = false
    @readable = false
    @stream.on 'readable', () =>
      @readable = true
      @trigger()
    @stream.on 'end', () =>
      @eof = true
      @trigger()
    @stream.on 'close', () =>
      @eof = true
      @trigger()

  trigger : () ->
    if @_cb?
      t = @_cb
      @_cb = null
      t()

  read : (cb) ->
    eof = false
    ret = null
    while not eof and not ret
      if @eof
        ret = @stream.read()
        eof = true
      else if @readable
        @readable = false
        ret = @stream.read @sz
      else
        await
          @_cb = defer()
    cb eof, ret
      
t = new Trickler()
b = new Batcher t, 10

eof = false
while not eof
  await b.read defer eof, buf
  console.log buf

