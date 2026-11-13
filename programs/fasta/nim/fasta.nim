# The Computer Language Benchmarks Game: fasta. Same algorithm as the C version
# (linear symbol lookup, LINELEN-wide lines). Output is buffered by the C stdio layer
# behind `stdout`, as in the C version.
import std/[os, strutils]

const
  IM = 139968'u32
  IA = 3877'u32
  IC = 29573'u32
  LINELEN = 60

var seed = 42'u32

template fastaRand(): float64 =
  seed = (seed * IA + IC) mod IM
  1.0 * float64(seed) / float64(IM)

const alu =
  "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" &
  "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" &
  "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" &
  "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" &
  "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" &
  "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" &
  "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

const iub = "acgtBDHKMNRSVWY"
const iubP = [0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02]

const homosapiens = "acgt"
const homosapiensP = [0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008]

proc repeatFasta(seq: string, n: int) =
  let len = seq.len
  var buffer = newString(len + LINELEN)
  for i in 0 ..< len: buffer[i] = seq[i]
  for i in 0 ..< LINELEN: buffer[len + i] = seq[i]

  var t = 0
  let wholeLines = n div LINELEN
  for _ in 0 ..< wholeLines:
    discard stdout.writeBuffer(addr buffer[t mod len], LINELEN)
    stdout.write '\n'
    t += LINELEN
  discard stdout.writeBuffer(addr buffer[t mod len], n - t)
  if n mod LINELEN != 0: stdout.write '\n'

proc linearLookup(len: int, p: openArray[float64], v: float64): int {.inline.} =
  for j in 0 ..< len - 1:
    if v > p[j]: inc result

proc randomFasta(symb: string, probability: openArray[float64], n: int) =
  let len = symb.len
  var p: array[16, float64]
  var buffer: array[LINELEN + 1, char]
  buffer[LINELEN] = '\n'

  p[0] = probability[0]
  for i in 1 ..< len: p[i] = probability[i] + p[i - 1]

  let lines = n div LINELEN
  for _ in 0 ..< lines:
    for k in 0 ..< LINELEN:
      let v = fastaRand()
      buffer[k] = symb[linearLookup(len, p, v)]
    discard stdout.writeBuffer(addr buffer[0], LINELEN + 1)
  let remainder = n - lines * LINELEN
  for k in 0 ..< remainder:
    let v = fastaRand()
    buffer[k] = symb[linearLookup(len, p, v)]
  discard stdout.writeBuffer(addr buffer[0], remainder)
  if n mod LINELEN != 0: stdout.write '\n'

let n = if paramCount() > 0: parseInt(paramStr(1)) else: 1000

stdout.write ">ONE Homo sapiens alu\n"
repeatFasta(alu, n * 2)

stdout.write ">TWO IUB ambiguity codes\n"
randomFasta(iub, iubP, n * 3)

stdout.write ">THREE Homo sapiens frequency\n"
randomFasta(homosapiens, homosapiensP, n * 5)
