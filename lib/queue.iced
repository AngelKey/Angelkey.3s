

#==================================================================

exports.Queue = class Queue 

  #---------------------------

  constructor : () -> 
    @_buffers = []
    @_n = 0
    @_eof = false

  #---------------------------

  set_eof : () -> @_eof = true

  #---------------------------

  push : (b) ->
    @_buffers.push b
    @_n += b.length
    if (c = @_cb)?
      @_cb = null
      c()


  #---------------------------

  flush : () ->
    ret = Buffer.concat @_buffers
    @_buffer = []
    return ret

  #---------------------------

  pop_bytes : (n) ->
    ret = []
    m = 0

    while (n_needed = n - m) > 0 and @_buffers.length
      b = @_buffers[0]
      l = b.length

      if l > n_needed
        # We're over what we need, so we need to take only a portion
        # of the front buffer...
        l = n_needed
        b = @_buffers[0][0...l]
        @_buffers[0] = @_buffers[0][l...]
      else
        # We're under or equal to what we need, so take the whole thing.
        @_buffers.shift()

      m += l
      @_n -= l
      ret.push b

    Buffer.concat ret

  #---------------------------

  read : (n, cb) ->
    console.log "read #{n} #{@_n}"
    while @_n < n and not @_eof
      console.log "Waiting..."
      await @_cb = defer()
      console.log "wait's over!"
    b = @pop_bytes n
    console.log "popping and returning...#{b.inspect()}"
    cb b
    
#==================================================================

