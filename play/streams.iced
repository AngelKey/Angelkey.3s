
argv = require('optimist').argv
fs = require 'fs'
stream = require 'stream'

fn = "#{argv._[0]}"

await fs.open fn, 'r', defer err, fd
if err
  console.log err
  process.exit -2

# will autoclose the FD....
reader = fs.createReadStream fn, { fd }

class Connector extends stream.Duplex

  constructor : ->
    super()
    @_chunks = []
    @_reads = 0

  _write : (chunk, encoding, cb) ->
    if @_reads > 0
      @_reads--
      @push chunk
      cb()
    else
      @_chunks.push [ chunk, cb ]

  _read : (sz) -> 
    if @_chunks.length
      c = @_chunks.pop()
      @push c[0]
      c[1]()
    else 
      @_reads++

class SlowDrain extends stream.Writable

  constructor : ->
    super()

  _write : (chunk, encoding, cb) ->
    len = chunk.length
    process.stdout.write chunk
    await setTimeout defer(), len/500
    cb()


sw = new SlowDrain()
connector = new Connector()
reader.pipe(connector).pipe(sw)
