# regex-redux, written for this suite after the Benchmarks Game's programs:
# Nim's standard std/re, which is PCRE2 with its JIT. One thread.

import std/re

const variants = [
  "agggtaaa|tttaccct",
  "[cgt]gggtaaa|tttaccc[acg]",
  "a[act]ggtaaa|tttacc[agt]t",
  "ag[act]gtaaa|tttac[agt]ct",
  "agg[act]taaa|ttta[agt]cct",
  "aggg[acg]aaa|ttt[cgt]ccct",
  "agggt[cgt]aa|tt[acg]accct",
  "agggta[cgt]a|t[acg]taccct",
  "agggtaa[cgt]|[acg]ttaccct",
]

const substs = [
  ("tHa[Nt]", "<4>"),
  ("aND|caN|Ha[DS]|WaS", "<3>"),
  ("a[NSt]|BY", "<2>"),
  ("<[^>]*>", "|"),
  ("\\|[^|][^|]*\\|", "-"),
]

proc countMatches(s: string, pattern: Regex): int =
  var pos = 0
  while true:
    let (first, last) = s.findBounds(pattern, pos)
    if first < 0: break
    inc result
    pos = last + 1

let input = stdin.readAll()
let sequence = input.replace(re">.*\n|\n", "")

for v in variants:
  echo v, " ", sequence.countMatches(re(v))

var replaced = sequence
for (pattern, by) in substs:
  replaced = replaced.replace(re(pattern), by)

echo ""
echo input.len
echo sequence.len
echo replaced.len
