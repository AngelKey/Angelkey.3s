
exports.constants =
  VERSION : 1
  PROT : "mkb.1"
  Header :
    FILE_VERSION : 1
    FILE_MAGIC   : [ 0x25, 0xb4, 0x84, 0xb8, 0x58, 0x36, 0x39, 0x9f ]
  poll_intervals:
    active : 30
    passive : 300

make_errors = () ->
  codes = 
    OK : [ 1, "OK" ]
    E_GENERIC : [ 100, "Generic error" ]
    E_INVAL : [ 101, "Invalid value" ]
    E_NOT_FOUND : [ 102, "Not found" ]
    E_QUERY : [ 103, "Bad query" ]
    E_DUPLICATE : [ 104, "Duplicated value" ]
    E_BAD_MAC : [ 105, "Message authentication failure" ]
    E_BAD_SIZE : [ 106, "Wrong size" ]

  reverse = {}
  for k, v in codes
    reverse[v[0]] = [k].concat v[1...]

  exports.status = codes
  exports.errors = {
    lookup : reverse
    to_string : (i) -> reverse[i]?.[1]
  }

make_errors()