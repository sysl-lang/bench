# The Computer Language Benchmarks Game: pidigits. A port of the C program (Mr Ledrug's), written
# for this suite: Gibbons' spigot over GMP through importc declarations of gmp.h's __gmpz_*
# symbols, output through `stdout`.
import std/[os, strutils]

{.passL: "-lgmp".}

type
  Mpz {.bycopy.} = object
    alloc, size: cint
    d: pointer

proc mpz_init(x: var Mpz) {.importc: "__gmpz_init", cdecl.}
proc mpz_init_set_ui(x: var Mpz, v: culong) {.importc: "__gmpz_init_set_ui", cdecl.}
proc mpz_add(r: var Mpz, a, b: var Mpz) {.importc: "__gmpz_add", cdecl.}
proc mpz_mul_ui(r: var Mpz, a: var Mpz, b: culong) {.importc: "__gmpz_mul_ui", cdecl.}
proc mpz_addmul_ui(r: var Mpz, a: var Mpz, b: culong) {.importc: "__gmpz_addmul_ui", cdecl.}
proc mpz_submul_ui(r: var Mpz, a: var Mpz, b: culong) {.importc: "__gmpz_submul_ui", cdecl.}
proc mpz_tdiv_q(q: var Mpz, n, d: var Mpz) {.importc: "__gmpz_tdiv_q", cdecl.}
proc mpz_get_ui(x: var Mpz): culong {.importc: "__gmpz_get_ui", cdecl.}
proc mpz_cmp(a, b: var Mpz): cint {.importc: "__gmpz_cmp", cdecl.}

var tmp1, tmp2, acc, den, num: Mpz

proc extractDigit(nth: culong): culong =
  # joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
  mpz_mul_ui(tmp1, num, nth)
  mpz_add(tmp2, tmp1, acc)
  mpz_tdiv_q(tmp1, tmp2, den)
  mpz_get_ui(tmp1)

proc eliminateDigit(d: culong) =
  mpz_submul_ui(acc, den, d)
  mpz_mul_ui(acc, acc, 10)
  mpz_mul_ui(num, num, 10)

proc nextTerm(k: culong) =
  let k2 = k * 2 + 1
  mpz_addmul_ui(acc, num, 2)
  mpz_mul_ui(acc, acc, k2)
  mpz_mul_ui(den, den, k2)
  mpz_mul_ui(num, num, k)

let n = if paramCount() > 0: parseInt(paramStr(1)) else: 27

mpz_init(tmp1)
mpz_init(tmp2)
mpz_init_set_ui(acc, 0)
mpz_init_set_ui(den, 1)
mpz_init_set_ui(num, 1)

var i = 0
var k: culong = 0
while i < n:
  inc k
  nextTerm(k)
  if mpz_cmp(num, acc) > 0: continue

  let d = extractDigit(3)
  if d != extractDigit(4): continue

  stdout.write char(ord('0') + int(d))
  inc i
  if i mod 10 == 0:
    stdout.write "\t:", i, "\n"
  eliminateDigit(d)

if n mod 10 != 0:
  stdout.write repeat(' ', 10 - n mod 10), "\t:", n, "\n"
