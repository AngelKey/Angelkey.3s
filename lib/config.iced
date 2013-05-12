
path = require 'path'
fs = require 'fs'
log = require './log'

#=========================================================================

exports.Config = class Config

  #-------------------

  constructor : () ->
    @json = null
    @loaded = false

  #-------------------

  init : (fn) ->
    @filename = if fn? then fn
    else if (f = process.env.MKB_CONFIG)? then f
    else path.join process.env.HOME, ".mkb.conf"

  #-------------------

  find : (file, cb) ->
    @init file
    await fs.exists @filename, defer @found
    cb @found

  #-------------------

  set : (key, val) ->
    parts = key.split "."
    @json = {} unless @json?
    d = @json
    for p in parts[0...(parts.length-1)]
      d[p] = {} unless d[p]?
      d = d[p]
    d[parts[parts.length-1]] = val

  #-------------------

  load : (cb) ->
    ok = true
    
    await fs.readFile @filename, defer err, file
    if err?
      log.error "Cannot read file #{@filename}: #{err}"
      ok = false

    if ok
      try
        @json = JSON.parse file
      catch e
        log.error "Invalid json in #{@filename}: #{e}"
        ok = false

    if ok 
      for key in [ 'aws', 'vault' ]
        unless @json?[key]?
          log.error "Missing JSON component '#{key}' in #{@filename}" unless @json?[key]?
          ok = false

    log.warn "Failed to load config" unless ok

    cb ok

  #-------------------

  file_extension : () ->
    @json.file_extension or "mke"

  #-------------------

  aws   : () -> @json.aws
  vault : () -> @json.vault
  email : () -> @json.email
  salt  : () -> @json.salt
  password : () -> @json.password
  sns   : () -> @json.sns
  sqs   : () -> @json.sqs

#=========================================================================
