# The Computer Language Benchmarks Game: reverse-complement. Same algorithm as the C version:
# each sequence line is complemented through a 256-entry table (characters without an entry are
# dropped) and stored reversed, then the record is written in 60-column lines.
import std/strutils

proc makeTable(): array[256, char] =
  const letters = "ABCDGHKMNRSTVWY"
  const complements = "TVGHCDMKNYSABWR"
  for i in 0 ..< letters.len:
    result[ord(letters[i])] = complements[i]
    result[ord(letters[i]) + 32] = complements[i]

const xtab = makeTable()

proc emit(rec: openArray[char], rlen: int) =
  var line: array[61, char]
  var e = rlen
  while e > 0:
    let x = min(e, 60)
    for k in 0 ..< x: line[k] = rec[e - 1 - k]
    line[x] = '\n'
    discard stdout.writeBuffer(addr line[0], x + 1)
    e -= x

let input = stdin.readAll()
var rec = newSeq[char](input.len + 1)
var rlen = 0
var pos = 0
while pos < input.len:
  var e = input.find('\n', pos)
  if e < 0: e = input.len
  if e > pos and input[pos] == '>':
    emit(rec, rlen)
    rlen = 0
    discard stdout.writeBuffer(unsafeAddr input[pos], e - pos)
    stdout.write '\n'
  else:
    for i in pos ..< e:
      let c = xtab[ord(input[i])]
      if c != '\0':
        rec[rlen] = c
        inc rlen
  pos = e + 1
emit(rec, rlen)
