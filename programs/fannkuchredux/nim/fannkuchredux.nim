# The Computer Language Benchmarks Game: fannkuch-redux. Same algorithm as the C version
# (Tompkin-Paige iterative permutation generation).
import std/[os, strutils]

var
  s, t: array[16, int32]
  maxflips: int32 = 0
  maxN = 0
  odd = false
  checksum: int32 = 0

proc flip(): int32 =
  for k in 0 ..< maxN: t[k] = s[k]
  var i: int32 = 1
  while true:
    var x = 0
    var y = int(t[0])
    while x < y:
      swap(t[x], t[y])
      inc x
      dec y
    inc i
    if t[t[0]] == 0: break
  i

proc rotate(n: int) {.inline.} =
  let c = s[0]
  for i in 1 .. n: s[i - 1] = s[i]
  s[n] = c

proc tk(n: int) =
  var i = 0
  var c: array[16, int32]
  while i < n:
    rotate(i)
    if c[i] >= i:
      c[i] = 0
      inc i
      continue
    inc c[i]
    i = 1
    odd = not odd
    if s[0] != 0:
      let f: int32 = if s[s[0]] != 0: flip() else: 1
      if f > maxflips: maxflips = f
      checksum += (if odd: -f else: f)

if paramCount() < 1:
  quit(1)
maxN = parseInt(paramStr(1))
if maxN < 3 or maxN > 15:
  quit(1)
for i in 0 ..< maxN: s[i] = int32(i)
tk(maxN)
echo checksum, "\nPfannkuchen(", maxN, ") = ", maxflips
