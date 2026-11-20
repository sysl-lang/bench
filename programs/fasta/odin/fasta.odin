// The Computer Language Benchmarks Game: fasta. Original, written for this benchmark. It mirrors the
// Game's fastest C program (fasta.gcc-3, Drake Diedrich), which is single-threaded: the symbol for
// each of the generator's IM states is looked up in a table built once from the cumulative
// probabilities (in single precision, as gcc-3 builds it), so the inner loop is one generator step
// and one load; whole buffers of 100 lines are filled with the newlines already in place and written
// in one call each; the repeated sequence is laid out once as len(alu) lines and written in whole
// copies. Bounds checks are off in the fill loops (#no_bounds_check), as C has none.
package main

import "core:os"
import "core:strconv"

IM :: 139968
IA :: 3877
IC :: 29573
LINELEN :: 60
BUFLINES :: 100

seed: u32 = 42

next_state :: #force_inline proc "contextless" () -> u32 {
	seed = (seed * IA + IC) % IM
	return seed
}

put :: proc(data: []u8) {
	os.write(os.stdout, data)
}

ALU :: "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" +
	"GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" +
	"CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" +
	"ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" +
	"GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" +
	"AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" +
	"AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

repeat_fasta :: proc(seq: string, n: int) {
	l := len(seq)
	// l lines of LINELEN, each starting where the previous ended: one whole period of the output.
	buf := make([]u8, (LINELEN + 1) * l)
	defer delete(buf)
	for i in 0 ..< l {
		for k in 0 ..< LINELEN {
			buf[i * (LINELEN + 1) + k] = seq[(i * LINELEN + k) % l]
		}
		buf[(i + 1) * (LINELEN + 1) - 1] = '\n'
	}
	whole := n / (l * LINELEN)
	for _ in 0 ..< whole {
		put(buf)
	}
	remaining := n - whole * l * LINELEN
	put(buf[:remaining + remaining / LINELEN])
	if n % LINELEN != 0 {
		put({'\n'})
	}
}

table: [IM]u8
line_buf: [(LINELEN + 1) * BUFLINES]u8

random_fasta :: proc(symb: string, prob: []f32, n: int) #no_bounds_check {
	sum := prob[0]
	j := 0
	for i := 0; i < IM && j < len(symb); i += 1 {
		r := 1.0 * f64(i) / f64(IM)
		if r >= f64(sum) {
			j += 1
			if j < len(prob) {
				sum += prob[j]
			}
		}
		table[i] = symb[min(j, len(symb) - 1)]
	}
	buf := line_buf[:]
	for l in 0 ..< BUFLINES {
		buf[l * (LINELEN + 1) + LINELEN] = '\n'
	}

	buffers := n / LINELEN / BUFLINES
	for _ in 0 ..< buffers {
		for l in 0 ..< BUFLINES {
			base := l * (LINELEN + 1)
			for k in 0 ..< LINELEN {
				buf[base + k] = table[next_state()]
			}
		}
		put(buf)
	}
	lines := n / LINELEN - buffers * BUFLINES
	for l in 0 ..< lines {
		base := l * (LINELEN + 1)
		for k in 0 ..< LINELEN {
			buf[base + k] = table[next_state()]
		}
	}
	partial := n - LINELEN * lines - buffers * BUFLINES * LINELEN
	for k in 0 ..< partial {
		buf[lines * (LINELEN + 1) + k] = table[next_state()]
	}
	put(buf[:lines * (LINELEN + 1) + partial])
	if n % LINELEN != 0 {
		put({'\n'})
	}
}

main :: proc() {
	n := 1000
	if len(os.args) > 1 {
		n, _ = strconv.parse_int(os.args[1])
	}
	iub_p := []f32{0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02}
	homosapiens_p := []f32{0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008}

	put(transmute([]u8)string(">ONE Homo sapiens alu\n"))
	repeat_fasta(ALU, n * 2)
	put(transmute([]u8)string(">TWO IUB ambiguity codes\n"))
	random_fasta("acgtBDHKMNRSVWY", iub_p, n * 3)
	put(transmute([]u8)string(">THREE Homo sapiens frequency\n"))
	random_fasta("acgt", homosapiens_p, n * 5)
}
