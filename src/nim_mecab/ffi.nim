## MeCab C API bindings (pure dynlib, no header required).

import nim_vendor_lib/vendor_lib

const mecabLib* = systemDynlib("mecab",
  macosPath = "/opt/homebrew/lib/libmecab.dylib")

type
  MecabT* = pointer

  MecabNodeT* {.pure, final.} = object
    prev*: ptr MecabNodeT
    next*: ptr MecabNodeT
    enext*: ptr MecabNodeT
    bnext*: ptr MecabNodeT
    surface*: cstring
    feature*: cstring
    id*: cuint
    length*: cushort
    rlength*: cushort
    rcAttr*: cushort
    lcAttr*: cushort
    posid*: cushort
    charType*: uint8
    stat*: uint8       # 0=Normal, 1=Unknown, 2=BOS, 3=EOS
    isbest*: uint8
    alpha*: cfloat
    beta*: cfloat
    prob*: cfloat
    wcost*: cshort
    cost*: clong

proc mecab_new2*(arg: cstring): MecabT {.importc, dynlib: mecabLib, raises: [].}
proc mecab_sparse_tonode*(m: MecabT, input: cstring): ptr MecabNodeT {.importc, dynlib: mecabLib, raises: [].}
proc mecab_sparse_tostr*(m: MecabT, input: cstring): cstring {.importc, dynlib: mecabLib, raises: [].}
proc mecab_destroy*(m: MecabT) {.importc, dynlib: mecabLib, raises: [].}
proc mecab_strerror*(m: MecabT): cstring {.importc, dynlib: mecabLib, raises: [].}
