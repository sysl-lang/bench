// The Computer Language Benchmarks Game: fasta. A port of the C program (Drake Diedrich's),
// written for this suite: the 139968-state generator, each symbol chosen by a linear scan of the
// cumulative probabilities, output through a buffered writer.
package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"

IM :: u32(139968)
IA :: u32(3877)
IC :: u32(29573)
SEED :: u32(42)
LINELEN :: 60

seed := SEED

fasta_rand :: #force_inline proc(max: f64) -> f64 {
	seed = (seed * IA + IC) % IM
	return max * f64(seed) / f64(IM)
}

ALU :: "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" +
	"GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" +
	"CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" +
	"ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" +
	"GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" +
	"AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" +
	"AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

IUB :: "acgtBDHKMNRSVWY"
IUB_P := [15]f64{0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02}

HOMOSAPIENS :: "acgt"
HOMOSAPIENS_P := [4]f64{0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008}

repeat_fasta :: proc(w: io.Writer, seq: string, n: int) {
	length := len(seq)
	buffer := make([]u8, length + LINELEN)
	defer delete(buffer)
	copy(buffer, seq)
	copy(buffer[length:], seq[:LINELEN])

	t := 0
	whole_lines := n / LINELEN
	for _ in 0 ..< whole_lines {
		io.write(w, buffer[t % length:][:LINELEN])
		io.write_byte(w, '\n')
		t += LINELEN
	}
	io.write(w, buffer[t % length:][:n - t])
	if n % LINELEN != 0 {
		io.write_byte(w, '\n')
	}
}

linear_lookup :: #force_inline proc(p: []f64, v: f64) -> int {
	i := 0
	for j in 0 ..< len(p) - 1 {
		if v > p[j] {
			i += 1
		}
	}
	return i
}

random_fasta :: proc(w: io.Writer, symb: string, probability: []f64, n: int) {
	length := len(symb)
	p := make([]f64, length)
	defer delete(p)
	buffer: [LINELEN + 2]u8
	buffer[LINELEN] = '\n'

	p[0] = probability[0]
	for i in 1 ..< length {
		p[i] = probability[i] + p[i - 1]
	}

	i := 0
	for ; i < n / LINELEN; i += 1 {
		for k in 0 ..< LINELEN {
			v := fasta_rand(1.0)
			buffer[k] = symb[linear_lookup(p, v)]
		}
		io.write(w, buffer[:LINELEN + 1])
	}
	remainder := n - (i * LINELEN)
	for k in 0 ..< remainder {
		v := fasta_rand(1.0)
		buffer[k] = symb[linear_lookup(p, v)]
	}
	io.write(w, buffer[:remainder])
	if n % LINELEN != 0 {
		io.write_byte(w, '\n')
	}
}

main :: proc() {
	n := 1000
	if len(os.args) > 1 {
		n, _ = strconv.parse_int(os.args[1])
	}

	out: bufio.Writer
	bufio.writer_init(&out, os.to_stream(os.stdout))
	defer bufio.writer_destroy(&out)
	w := bufio.writer_to_stream(&out)

	io.write_string(w, ">ONE Homo sapiens alu\n")
	repeat_fasta(w, ALU, n * 2)

	io.write_string(w, ">TWO IUB ambiguity codes\n")
	random_fasta(w, IUB, IUB_P[:], n * 3)

	io.write_string(w, ">THREE Homo sapiens frequency\n")
	random_fasta(w, HOMOSAPIENS, HOMOSAPIENS_P[:], n * 5)

	bufio.writer_flush(&out)
}
