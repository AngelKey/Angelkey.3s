
BigNum = require 'bignum'

class Base58Builder
  constructor: ->
    @alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    @base = @alphabet.length

  encode: (buffer) ->
    num = BigNum.fromBuffer buffer
    str = ''
    while num.ge @base
      mod = num.mod @base
      str = @alphabet[mod] + str
      num = (num.sub mod).div @base
    res = @alphabet[num] + str

    pad = []
    for c in buffer
      if c is 0 then pad.push @alphabet[0]
      else break

    pad.join('') + res

  decode: (str) ->
    num = BigNum 0
    base = BigNum 1
    for char, index in str.split(//).reverse()
      if (char_index = @alphabet.indexOf(char)) == -1
        throw new Error('Value passed is not a valid Base58 string.')
      num = num.add base.mul char_index
      base = base.mul @base
    num.toBuffer()

# Export module
module.exports = new Base58Builder()

