# The Computer Language Benchmarks Game: spectral norm. Same algorithm as the C version.
import std/[math, os, strutils]

proc evalA(i, j: int32): float64 {.inline.} =
  1.0 / float64((i + j) * (i + j + 1) div 2 + i + 1)

proc evalATimesU(n: int32, u: ptr UncheckedArray[float64], au: ptr UncheckedArray[float64]) =
  for i in 0'i32 ..< n:
    au[i] = 0
    for j in 0'i32 ..< n:
      au[i] += evalA(i, j) * u[j]

proc evalAtTimesU(n: int32, u: ptr UncheckedArray[float64], au: ptr UncheckedArray[float64]) =
  for i in 0'i32 ..< n:
    au[i] = 0
    for j in 0'i32 ..< n:
      au[i] += evalA(j, i) * u[j]

proc evalAtATimesU(n: int32, u, atau, v: ptr UncheckedArray[float64]) =
  evalATimesU(n, u, v)
  evalAtTimesU(n, v, atau)

let n: int32 = if paramCount() == 1: int32(parseInt(paramStr(1))) else: 100
var ub = newSeq[float64](n)
var vb = newSeq[float64](n)
var tb = newSeq[float64](n)
let u = cast[ptr UncheckedArray[float64]](addr ub[0])
let v = cast[ptr UncheckedArray[float64]](addr vb[0])
let tmp = cast[ptr UncheckedArray[float64]](addr tb[0])
for i in 0 ..< n: u[i] = 1
for _ in 0 ..< 10:
  evalAtATimesU(n, u, v, tmp)
  evalAtATimesU(n, v, u, tmp)
var vBv, vv = 0.0
for i in 0 ..< n:
  vBv += u[i] * v[i]
  vv += v[i] * v[i]
echo formatFloat(sqrt(vBv / vv), ffDecimal, 9)
