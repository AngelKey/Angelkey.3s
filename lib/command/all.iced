
optim = require 'optimist'
{ArgumentParser} = require 'argparse'
{Base} = require './base'

##=======================================================================

class Main

  #---------------------------------

  constructor : ->
    @ap = new ArgumentParser 
      addHelp : true
      version : '0.0.1'
      description : 'Backup files to AWS glacier'
      prog : process.argv[1]

    # Add the base options that are useful for all subcommands
    Base.add_options @ap

    list = [ 
      "enc",
      "dec"
    ]

    @commands = {}

    for m in list
      mod = require './#{m}'
      obj = new mod.Command()
      obj.add_options @ap
      
    for pair of list
      for n in pair[1]
        @commands[n] = pair[0]

  #---------------------------------

  help : () ->


  #---------------------------------

  run : () ->
    ok = true
    if process.argv.length >= 3 and (maker = @commands[process.argv[2]])?
      obj = maker()
      await obj.run process.argv[2...], defer ok
    else
      @help()
      ok = false
    process.exit if ok then 0 else -2

##=======================================================================

exports.run = () -> (new Main).run()

##=======================================================================
