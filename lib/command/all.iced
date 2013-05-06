

##=======================================================================

class Main

  constructor : ->
    commands = [
      "dec"
      "enc"
      "upload"
      "download"
      "init"
    ]
    for c in command
      @include c

  include : (c) ->
    require("../lib/command/#{c}").bind(@)


##=======================================================================

exports.run = () ->
