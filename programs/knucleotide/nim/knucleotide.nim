# The Computer Language Benchmarks Game: k-nucleotide. Same algorithm as the C version:
# one pass per oligonucleotide length over the encoded sequence, counting 2-bit keys in a hash
# table (here the standard library's Table), run sequentially.
import std/[algorithm, strutils, tables]

# A=0, C=1, G=2, T=3, for either case.
proc codeForNucleotide(c: char): uint8 {.inline.} =
  case int(c) and 7
  of 3: 1
  of 7: 2
  of 4: 3
  else: 0

proc countAll(poly: openArray[uint8], len: int): Table[uint64, uint32] =
  result = initTable[uint64, uint32]()
  var key = 0'u64
  let mask = (1'u64 shl (2 * len)) - 1
  for i in 0 ..< len - 1:
    key = ((key shl 2) and mask) or poly[i]
  for i in len - 1 ..< poly.len:
    key = ((key shl 2) and mask) or poly[i]
    inc result.mgetOrPut(key, 0'u32)

proc frequencies(poly: openArray[uint8], len: int) =
  let table = countAll(poly, len)
  var elements = newSeqOfCap[(uint64, uint32)](table.len)
  for k, v in table: elements.add (k, v)
  elements.sort(proc(a, b: (uint64, uint32)): int =
    if a[1] != b[1]: (if a[1] > b[1]: -1 else: 1)
    else: (if a[0] < b[0]: -1 else: 1))

  let total = float32(poly.len - len + 1)
  for (k, v) in elements:
    var name = newString(len)
    var key = k
    for j in countdown(len - 1, 0):
      name[j] = "ACGT"[int(key and 3)]
      key = key shr 2
    let pct = 100.0'f32 * float32(v) / total
    stdout.write name, " ", formatFloat(float64(pct), ffDecimal, 3), "\n"
  stdout.write "\n"

proc count(poly: openArray[uint8], oligo: string) =
  let table = countAll(poly, oligo.len)
  var key = 0'u64
  for c in oligo: key = (key shl 2) or codeForNucleotide(c)
  let n = table.getOrDefault(key, 0'u32)
  stdout.write n, "\t", oligo, "\n"

let input = stdin.readAll()

# Find the start of the third polynucleotide.
var pos = 0
while pos < input.len and not input.continuesWith(">THREE", pos):
  let nl = input.find('\n', pos)
  pos = if nl < 0: input.len else: nl + 1
block:
  let nl = input.find('\n', pos)
  pos = if nl < 0: input.len else: nl + 1

var poly = newSeqOfCap[uint8](input.len - min(pos, input.len))
while pos < input.len and input[pos] != '>':
  var e = input.find('\n', pos)
  if e < 0: e = input.len
  for i in pos ..< e: poly.add codeForNucleotide(input[i])
  pos = e + 1

frequencies(poly, 1)
frequencies(poly, 2)
count(poly, "GGT")
count(poly, "GGTA")
count(poly, "GGTATT")
count(poly, "GGTATTTTAATT")
count(poly, "GGTATTTTAATTTATAGT")
