// The Computer Language Benchmarks Game: k-nucleotide. A port of the C program (Jeremy Zerfas's),
// written for this suite: one pass per oligonucleotide length over the encoded sequence, counting
// 2k-bit keys in a hash table (Odin's built-in map keyed by u64), run sequentially.
package main

import "core:bufio"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Element :: struct {
	key:   u64,
	value: u32,
}

// A=0, C=1, G=2, T=3, for either case. Indexed by c & 7: 'A' is 1, 'C' is 3, 'T' is 4, 'G' is 7.
CODES := [8]u8{0, 0, 0, 1, 3, 0, 0, 2}

count_all :: proc(poly: []u8, length: int) -> map[u64]u32 {
	counts := make(map[u64]u32)
	key: u64 = 0
	mask := (u64(1) << uint(2 * length)) - 1
	for i in 0 ..< length - 1 {
		key = ((key << 2) & mask) | u64(poly[i])
	}
	for i in length - 1 ..< len(poly) {
		key = ((key << 2) & mask) | u64(poly[i])
		counts[key] += 1
	}
	return counts
}

frequencies :: proc(poly: []u8, length: int) {
	counts := count_all(poly, length)
	defer delete(counts)
	elements := make([dynamic]Element, 0, len(counts))
	defer delete(elements)
	for k, v in counts {
		append(&elements, Element{k, v})
	}

	slice.sort_by(elements[:], proc(a, b: Element) -> bool {
		if a.value != b.value {
			return a.value > b.value
		}
		return a.key < b.key
	})

	acgt := "ACGT"
	name: [32]u8
	for e in elements {
		key := e.key
		for j := length - 1; j >= 0; j -= 1 {
			name[j] = acgt[key & 3]
			key >>= 2
		}
		pct := f32(100.0) * f32(e.value) / f32(len(poly) - length + 1)
		fmt.printf("%s %.3f\n", string(name[:length]), pct)
	}
	fmt.printf("\n")
}

count :: proc(poly: []u8, oligo: string) {
	counts := count_all(poly, len(oligo))
	defer delete(counts)
	key: u64 = 0
	for i in 0 ..< len(oligo) {
		key = (key << 2) | u64(CODES[oligo[i] & 7])
	}
	fmt.printf("%d\t%s\n", counts[key], oligo)
}

main :: proc() {
	r: bufio.Reader
	bufio.reader_init(&r, os.to_stream(os.stdin))
	defer bufio.reader_destroy(&r)

	// Find the start of the third polynucleotide.
	for {
		line, err := bufio.reader_read_slice(&r, '\n')
		if len(line) == 0 && err != nil {
			break
		}
		if strings.has_prefix(string(line), ">THREE") {
			break
		}
	}

	poly := make([dynamic]u8, 0, 1 << 20)
	defer delete(poly)
	for {
		line, err := bufio.reader_read_slice(&r, '\n')
		if len(line) == 0 && err != nil {
			break
		}
		if line[0] == '>' {
			break
		}
		for c in line {
			if c != '\n' {
				append(&poly, CODES[c & 7])
			}
		}
	}

	frequencies(poly[:], 1)
	frequencies(poly[:], 2)
	count(poly[:], "GGT")
	count(poly[:], "GGTA")
	count(poly[:], "GGTATT")
	count(poly[:], "GGTATTTTAATT")
	count(poly[:], "GGTATTTTAATTTATAGT")
}
