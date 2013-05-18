
{Keys,Engine,secure_bufeq} = require '../../lib/block'
{rng,prng} = require 'crypto'
{status} = require '../../lib/constants'

twiddle_byte = (buf, i) ->
  buf[i] = (buf[i] + 1) % 0x100

# Run a test:
#  1. Generate a random block of length psize
#  2. Generate a random key set
#  3. Encrypt the block in step 1.
#  4. Check that the encryption is the right size
#  5. Decrypt and check it against the original
#  6. Corrupt it, and check that it fails the MAC
# 
test = (T, psize, esize) ->
  keys = new Keys prng Keys.raw_length()
  input = prng psize
  eng = new Engine keys
  eblock = eng.encrypt input
  T.assert ((l = eblock.length) is esize), "output block len #{l} != #{esize}"
  [rc,pblock] = eng.decrypt eblock
  T.assert (rc is status.OK), "decryption failed w/ code #{rc}"
  T.assert (secure_bufeq pblock, input), "Failed to get out same block"
  twiddle_byte eblock, 18
  [rc,_] = eng.decrypt eblock
  T.assert (rc is status.E_BAD_MAC), "mac should fail on corrupted block"

exports.test_small_1 = (T, cb) ->
  test T, 15, 64
  cb()
