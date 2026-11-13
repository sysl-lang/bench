# The Computer Language Benchmarks Game: mandelbrot. Same algorithm as the C version.
import std/[os, strutils]

let w = parseInt(paramStr(1))
let h = w
const iter = 50
const limit = 2.0
var bitNum = 0
var byteAcc: uint8 = 0

stdout.write "P4\n", w, " ", h, "\n"

let wf = float64(w)
let hf = float64(h)
var y = 0.0
while y < hf:
  var x = 0.0
  while x < wf:
    var zr, zi, tr, ti = 0.0
    let cr = 2.0 * x / wf - 1.5
    let ci = 2.0 * y / hf - 1.0

    var i = 0
    while i < iter and (tr + ti <= limit * limit):
      zi = 2.0 * zr * zi + ci
      zr = tr - ti + cr
      tr = zr * zr
      ti = zi * zi
      inc i

    byteAcc = byteAcc shl 1
    if tr + ti <= limit * limit: byteAcc = byteAcc or 1
    inc bitNum

    if bitNum == 8:
      stdout.write char(byteAcc)
      byteAcc = 0
      bitNum = 0
    elif x == wf - 1:
      byteAcc = byteAcc shl (8 - w mod 8)
      stdout.write char(byteAcc)
      byteAcc = 0
      bitNum = 0
    x += 1
  y += 1
