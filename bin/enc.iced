
env = require './lib/env'
cmd = require './lib/command'

#=========================================================================

class Command extends cmd.Base
   
  #-----------------

  @OPTS = 
    o : 
      alias : "output"
      describe : "output file to write to"
    r :
      alias : "remove"
      describe : "remove the original file after encryption"
      boolean : true

  #-----------------
   
  constructor : () ->
    super Command.OPTS

#=========================================================================
