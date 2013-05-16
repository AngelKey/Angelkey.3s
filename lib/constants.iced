
exports.constants =
  VERSION : 1
  PROT : "mkb.1"
  Preamble :
    FILE_VERSION : 1
    FILE_MAGIC   : [ 0x25, 0xb4, 0x84, 0xb8, 0x58, 0x36, 0x39, 0x9f ]
  poll_intervals:
    active : 30
    passive : 300

exports.status =
  OK : 1
  E_GENERIC : 100
  E_INVAL : 101
  E_NOT_FOUND : 102
  E_QUERY : 103
  E_DUPLICATE : 104