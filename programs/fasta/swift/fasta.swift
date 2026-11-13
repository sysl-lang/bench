/* The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   Swift port, for this suite, of the C program in ../c (Drake Diedrich's
   fasta.gcc-2): the same generator, the same linear scan over the cumulative
   probabilities, and the same block-at-a-time output through stdio. The
   Benchmarks Game's own Swift programs either build a String a Character at a
   time or run several threads, so neither is the same work as the C program.
*/

import Darwin

let IM: UInt32 = 139968
let IA: UInt32 = 3877
let IC: UInt32 = 29573
var seed: UInt32 = 42

@inline(__always)
func fastaRand(_ state: inout UInt32, _ max: Double) -> Double {
    state = (state &* IA &+ IC) % IM
    return max * Double(state) / Double(IM)
}

let alu: [UInt8] = Array((
  "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" +
  "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" +
  "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" +
  "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" +
  "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" +
  "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" +
  "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA").utf8)

let iub: [UInt8] = Array("acgtBDHKMNRSVWY".utf8)
let iubP: [Double] = [0.27, 0.12, 0.12, 0.27,
                      0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02]

let homosapiens: [UInt8] = Array("acgt".utf8)
let homosapiensP: [Double] = [0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008]

let LINELEN = 60

func repeatFasta(_ seq: [UInt8], _ n: Int) {
    let len = seq.count
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len + LINELEN)

    for i in 0..<len + LINELEN { buffer[i] = seq[i % len] }

    var t = 0
    let wholeLines = n / LINELEN

    for _ in 0..<wholeLines {
        fwrite(buffer + t % len, 1, LINELEN, stdout)
        putchar(10)
        t += LINELEN
    }

    fwrite(buffer + t % len, 1, n - t, stdout)
    buffer.deallocate()

    if n % LINELEN != 0 { putchar(10) }
}

@inline(__always)
func linearLookup(_ p: UnsafePointer<Double>, _ len: Int, _ v: Double) -> Int {
    var i = 0

    for j in 0..<len - 1 { i += v > p[j] ? 1 : 0 }

    return i
}

func randomFasta(_ symb: [UInt8], _ probability: [Double], _ n: Int) {
    let len = symb.count
    var p = probability

    for i in 1..<len { p[i] = probability[i] + p[i - 1] }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: LINELEN + 2)
    buffer[LINELEN] = 10
    var state = seed

    p.withUnsafeBufferPointer { cumulative in
        symb.withUnsafeBufferPointer { symbols in
            let base = cumulative.baseAddress!

            for _ in 0..<n / LINELEN {
                for k in 0..<LINELEN {
                    buffer[k] = symbols[linearLookup(base, len, fastaRand(&state, 1.0))]
                }

                fwrite(buffer, 1, LINELEN + 1, stdout)
            }

            let remainder = n - (n / LINELEN) * LINELEN

            for k in 0..<remainder {
                buffer[k] = symbols[linearLookup(base, len, fastaRand(&state, 1.0))]
            }

            fwrite(buffer, 1, remainder, stdout)
        }
    }

    seed = state
    buffer.deallocate()

    if n % LINELEN != 0 { putchar(10) }
}

let n = CommandLine.argc > 1 ? Int(CommandLine.arguments[1])! : 1000

print(">ONE Homo sapiens alu", terminator: "\n")
fflush(stdout)
repeatFasta(alu, n * 2)

print(">TWO IUB ambiguity codes", terminator: "\n")
fflush(stdout)
randomFasta(iub, iubP, n * 3)

print(">THREE Homo sapiens frequency", terminator: "\n")
fflush(stdout)
randomFasta(homosapiens, homosapiensP, n * 5)
