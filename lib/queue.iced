

#==================================================================

exports.Queue = class Queue 

  #---------------------------

  constructor : () -> 
    @_buffers = []
    @_n = 0

  #---------------------------

  push : (b) ->
    @_buffers.push b
    @_n += b.length
    if (c = @_cb)?
      @_cb = null
      c()

  #---------------------------

  pop_bytes : (n) ->
    ret = []
    m = 0

    while m < n
      b = @_buffers[0]
      l = b.length

      if (l + m) > n
        # We're over what we need, so we need to take only a portion
        # of the front buffer...
        l = l + m - n
        b = @_buffers[0...l]
        @_buffers[0] = @_buffers[l...]
      else
        # We're under or equal to what we need, so take the whole thing.
        @_buffers.shift()

      m += l
      @_n -= l
      ret.push b

    return Buffer.concat ret

  #---------------------------

  read : (n, cb) ->
    while n < @_n
      await @_cb = defer()
    b = @pop_bytes n
    cb b
    
#==================================================================

