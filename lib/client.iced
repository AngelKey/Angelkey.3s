
rpc = require 'framed-msgpack-rpc'
{constants,status} = require './constants'
log = require './log'

#=========================================================================

exports.Client = class Client

  constructor : ({@path}) ->
    @_x = new rpc.RobustTransport { @path }

  init : (cb) ->
    await @_x.connect defer err
    if err?
      log.error "Error connecting to socket: #{err}"
      @_x = null
    else
      @_cli = new rpc.Client @_x, constants.PROT
    cb (not err)

  _call_check : (meth, arg, cb, codes = [ status.OK ]) ->
    ok = false
    await @_cli.invoke meth, arg, defer err, res
    if err?
      log.error "Error in #{meth}: #{err}"
    else if not (res?.rc in codes)
      log.error "Got bad code from #{meth}: #{res.rc}"
    else
      ok = true
    cb if ok then res else null

  ping : (cb) ->
    await @_call_check "ping", {}, defer res
    cb res?

  send_download : (obj, cb) ->
    await @_call_check "download", obj, defer res
    cb res?

  @make : (path, cb) ->
    x = new Client { path }
    await x.init defer ok
    x = null unless ok 
    cb x

#=========================================================================

_g = {}

exports.client = () -> _g.client

exports.init_client = (path, cb) ->
  await Client.make path, defer _g.client
  cb _g.client?

#=========================================================================
