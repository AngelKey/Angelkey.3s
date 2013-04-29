
exports.Stream = class Stream

  constructor : (@fd, @filename, @bufsz) ->

  read : (cb, sz) ->

