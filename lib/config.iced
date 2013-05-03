
path = require 'path'
fs = require 'fs'
log = require './log'

#=========================================================================

exports.Config = class Config

  #-------------------

  constructor : () ->
    @json = null

  #-------------------

  init : (fn) ->
    @filename = if fn? then fn
    else if (f = process.env.MKBKP_CONFIG)? then f
    else path.join process.env.HOME, ".mkbkp.conf"

  #-------------------

  load : (fn, cb) ->
    @init fn
    
    await fs.exists @filename, defer ok

    if not ok
      log.error "Cannot find config file #{@filename}"
    else
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
    @json.file_extension or ".mke"

  #-------------------

  aws   : () -> @json.aws
  vault : () -> @json.vault
  email : () -> @json.email
  salt  : () -> @json.salt
  password : () -> @json.password

#=========================================================================
