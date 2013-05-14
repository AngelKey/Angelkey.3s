
rpc = require 'framed-msgpack-rpc'
{constants} = require './constants'

#=========================================================================

_cli = null

exports.make_client = ({@config}, cb) ->

  return cb _cli if _cli?

  opts = 
    path : @config.sockfile()
  x = new rpc.RobustTransport opts
  await x.connect defer err
  if err?
    log.error "Error connecting to socket: #{err}"
    x = null
  if x?
    ret = _cli = new rpc.Client x, constants.PROT
  cb ret

#=========================================================================

exports.check_res = (call, err, res, codes = [ constants.RPC.OK ]) ->
  ok = false
  if err?
    log.error "Error in #{call}: #{err}"
  else if not (res?.rc in codes)
    log.error "Got bad code from #{call}: #{res.rc}"
  else
    ok = true
  ok
  

#=========================================================================
