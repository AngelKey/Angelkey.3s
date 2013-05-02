
read = require 'read'
log = require './log'
crypto = require 'crypto'

#=========================================================================

exports.PasswordManager = class PasswordManager

  constructor : () ->
    # This is a sensible default.  Let's not bore the users with lots of 
    # paramters they don't want to tweak.
    @pbkdf_iters = 1024

  #-------------------

  init : (opts) ->
    @opts = opts
    true

  #-------------------

  _prompt_1 : (prompt, cb) ->
    console.log "X1"
    await read { prompt : "#{prompt}> ", silent : true }, defer err, res
    console.log "X2"
    if err
      log.error "In prompt: #{err}"
      res = null
    else if res?
      res = (res.split /\s+/).join ''
      res = null if res.length is 0
    cb res

  #-------------------

  prompt_for_old_pw : (cb) ->
    await @_prompt_1 'password', defer pw
    cb pw

  #-------------------

  prompt_for_pw : (is_new, cb) ->
    if is_new then @prompt_for_new_pw cb else @prompt_for_old_pw cb

  #-------------------

  prompt_for_new_pw : (cb) ->
    go = true
    res = null
    while go and not res
      await @_prompt_1 'passwrd', defer pw1
      if pw1?
        await @_prompt_1 'confirm', defer pw2
        if pw1 is pw2 then res = pw1
        else log.warn "Password didn't match"
      else
        go = false
    cb res

  #-------------------

  derive_key_material : (sz, cb) ->
    ret = null
    if not (salt = @opts.salt)?
      log.error "No salt given; can't derive keys"
    else
      await @get_password defer pw
      if not pw
        log.error "No password given; can't derive keys"

    if pw? and salt?
      await crypto.pbkdf2 pw, salt, sz, @pbkdf_iters, defer err, ret
      if err
        log.error "PBKDF2 failed: #{err}"

    cb ret
    
  #-------------------

  get_password : (is_new, cb) ->
    if not @_pw?
      if not (pw = @opts.password)? and not @opts.no_prompt
        await @prompt_for_pw is_new, defer pw
    @_pw = pw
    cb @_pw

#=========================================================================
