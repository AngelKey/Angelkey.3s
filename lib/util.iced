
exports.rmkey = (obj, key) ->
  ret = obj[key]
  delete obj[key]
  ret

