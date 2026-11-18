// regex-redux, written for this suite after the Benchmarks Game's programs: Odin's standard
// core:text/regex, every match walked with its iterator. One thread.
package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:text/regex"

variants := [?]string{
	"agggtaaa|tttaccct",
	"[cgt]gggtaaa|tttaccc[acg]",
	"a[act]ggtaaa|tttacc[agt]t",
	"ag[act]gtaaa|tttac[agt]ct",
	"agg[act]taaa|ttta[agt]cct",
	"aggg[acg]aaa|ttt[cgt]ccct",
	"agggt[cgt]aa|tt[acg]accct",
	"agggta[cgt]a|t[acg]taccct",
	"agggtaa[cgt]|[acg]ttaccct",
}

substs := [?][2]string{
	{"tHa[Nt]", "<4>"},
	{"aND|caN|Ha[DS]|WaS", "<3>"},
	{"a[NSt]|BY", "<2>"},
	{"<[^>]*>", "|"},
	{`\|[^|][^|]*\|`, "-"},
}

count_matches :: proc(s, pattern: string) -> int {
	it, err := regex.create_iterator(s, pattern)
	assert(err == nil)
	defer regex.destroy(it)
	n := 0
	for _ in regex.match_iterator(&it) {
		n += 1
	}
	return n
}

replace_all :: proc(s, pattern, with: string) -> string {
	it, err := regex.create_iterator(s, pattern)
	assert(err == nil)
	defer regex.destroy(it)
	b := strings.builder_make(0, len(s))
	last := 0
	for capture in regex.match_iterator(&it) {
		span := capture.pos[0]
		strings.write_string(&b, s[last:span[0]])
		strings.write_string(&b, with)
		last = span[1]
	}
	strings.write_string(&b, s[last:])
	return strings.to_string(b)
}

main :: proc() {
	data, err := os.read_entire_file(os.stdin, context.allocator)
	assert(err == nil)
	input := string(data)

	// `.` matches a newline here, so a header line is `>` and every character up to its newline.
	sequence := replace_all(input, ">[^\n]*\n|\n", "")

	for v in variants {
		fmt.println(v, count_matches(sequence, v))
	}

	replaced := sequence
	for s in substs {
		replaced = replace_all(replaced, s[0], s[1])
	}

	fmt.println()
	fmt.println(len(input))
	fmt.println(len(sequence))
	fmt.println(len(replaced))
}
