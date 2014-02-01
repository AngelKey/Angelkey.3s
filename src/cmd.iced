
{encrypt,decrypt} = require 'triplesec'
read = require 'read'
{make_esc} = require 'iced-error'
fs = require 'fs'
path = require 'path'

#======================================================

usage =  ->
  console.error """
#{path.basename process.argv[1]} [opts] <enc|dec> [file]

Options:
  -k/--key <key>              the key to use
  -o/--output <file>          the file to output to
  -i/--input-encoding <enc>   the input encoding to use
  -e/--output-encoding <enc>  the output encoding to write with

If no file given, will read from stdin.  If no output file, will write to standard
output.
"""

#======================================================

class Cmd

  #------------------------
  
  constructor : () ->
    @filename = null
    @cmd = null
    @_do_enc = false

  #------------------------

  check_encoding : (e) -> 
    if not(e) or (e in ['hex', 'base64', 'binary', 'none' ]) then null
    else new Error "bad encoding #{e}"

  get_encoding : (e) ->
    if not(e) or e in [ 'binary', 'none'] then null
    else e

  #------------------------

  parse_args : (cb) ->
    err = null
    @argv = require('optimist').
            alias('k', 'key').
            alias('o', 'output').
            alias('i', 'input-encoding').
            alias('h', 'help').
            boolean('h').
            alias('e', 'output-encoding').argv

    if @argv._.length < 1
      err = new Error 'Need an enc/dec comand'
    else if @argv._.length > 2
      err = new Error 'Can only handle 2 arguments at most'
    else 
      @filename = @argv._[1] if @argv._.length is 2
      cmd = @argv._[0]
      if cmd in [ 'enc', 'encrypt' ] 
        @cmd = encrypt
        @_do_enc = true
      else if cmd in [ 'dec', 'decrypt' ] 
        @cmd = decrypt
      else
        err = new Error 'Can only support enc or dec'
    err = @check_encoding @argv.i unless err?
    err = @check_encoding @argv.e unless err?
    unless err?
      if not @filename and not @argv.k
        err = new Error "Can't read a key and the data from standard input!"
    cb err

  #------------------------

  get_input : (cb) ->
    if @filename
      await fs.readFile @filename, defer err, @data
    else
      await @consume_stdin defer err, @data
    cb err

  #------------------------

  consume_stdin : (cb) ->
    bufs = []
    s = process.stdin
    fin = (err, data) ->
      if cb
        tcb = cb
        cb = null
        tcb err, data
    s.resume()
    s.on 'data', (buf) ->
      bufs.push buf
    s.on 'err', (err) -> 
      fin err, null
    s.on 'end', () -> 
      fin null, Buffer.concat(bufs)
  
  #------------------------

  get_key : (cb) ->
    @key = err = null
    unless (@key = @argv.k)?
      loop
        match = false
        await read { prompt : "password ----->", silent : true, replace : '*' }, defer err, @key
        if not(err?) and @_do_enc
          await read { prompt : "password (again)>", silent : true, replace : '*' }, defer err, p2
          match = (@key is p2) unless err?
        break if match or err or not(@_do_enc)
    cb err, @key

  #------------------------

  get_in_data : () -> 
    if (e = @get_encoding(@argv.i))?
      s = @data.toString('utf8')
      ret = new Buffer s, e
    else 
      ret = @data
    return ret

  #------------------------

  do_cmd : (cb) ->
    await @cmd { key : (new Buffer @key, 'utf8'), data : @get_in_data() }, defer err, @out_data
    cb err

  #------------------------

  write_output : (cb) ->
    if (e = @get_encoding @argv.e)?
      d = @out_data.toString(e)
      e = "utf8"
    else 
      d = @out_data
      e = null
    if @argv.o
      await fs.writeFile @argv.o, d, e, defer err
    else
      await process.stdout.write d, e, defer err
    cb err

  #------------------------

  run : (cb) ->
    esc = make_esc cb, "Cmd::run"
    await @parse_args esc defer()
    if @argv.h
      usage()
    else
      await @get_key esc defer()
      await @get_input esc defer()
      await @do_cmd esc defer()
      await @write_output esc defer()
    cb null

  #------------------------

#======================================================

exports.main = main = ->
  await (new Cmd).run defer err
  if err?
    console.error err.message
    rc = -2
  else
    rc = 0
  process.exit rc

#======================================================
