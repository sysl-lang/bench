// The Computer Language Benchmarks Game: reverse-complement. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (revcomp.gcc-9, Jeremy Zerfas): the input is
// read whole; each record's output (its reverse complement in 60-column lines) is cut into chunks of
// lines that one thread per core fills; characters are complemented two at a time through a
// 65,536-entry table of byte pairs (gcc-9's idea, from roman blog's C++ program); and when a record
// is made of full 60-character lines (every fasta file is, but for its last line), the sequence is
// read straight from the input with no pass to remove the newlines, as gcc-9's fast path does. Any
// other record is first copied without its newlines. The whole output is written in one call. Bounds
// checks are off in the fill loops (#no_bounds_check), as C has none.
package main

import "core:bytes"
import "core:os"
import "core:thread"

LINE :: 60

xtab: [256]u8
// pair[b0 | b1 << 8] is the complement of the two bytes b0 b1 reversed: comp(b1) | comp(b0) << 8.
pair: [65536]u16

// dst gets src's reverse complement.
rev_comp :: #force_inline proc(dst: [^]u8, src: []u8) #no_bounds_check {
	i := 0
	e := len(src)
	for e >= 2 {
		v := (^u16le)(&src[e - 2])^
		(^u16le)(&dst[i])^ = u16le(pair[v])
		e -= 2
		i += 2
	}
	if e == 1 {
		dst[i] = xtab[src[0]]
	}
}

// A record's sequence: either `seq` holds raw input in full 61-byte lines (`raw`), or it holds the
// sequence with its newlines removed.
Record :: struct {
	seq: []u8,
	len: int, // characters, without newlines
	raw: bool,
}

// The sequence characters [a, b) as at most two contiguous slices of r.seq.
segments :: #force_inline proc(r: Record, a, b: int, segs: ^[2][]u8) -> int #no_bounds_check {
	if !r.raw {
		segs[0] = r.seq[a:b]
		return 1
	}
	la := a / LINE
	lb := (b - 1) / LINE
	pa := a + la
	if la == lb {
		segs[0] = r.seq[pa:b + lb]
		return 1
	}
	segs[0] = r.seq[pa:(la + 1) * (LINE + 1) - 1]
	segs[1] = r.seq[(la + 1) * (LINE + 1):b + lb]
	return 2
}

Job :: struct {
	r:           Record,
	dst:         [^]u8,
	first, last: int,
}

// Output lines [first, last) of the record (each LINE characters and a newline, the last shorter).
fill_lines :: proc(job: ^Job) #no_bounds_check {
	r := job.r
	segs: [2][]u8
	for l in job.first ..< job.last {
		end := r.len - l * LINE
		x := min(end, LINE)
		o := job.dst[l * (LINE + 1):]
		nseg := segments(r, end - x, end, &segs)
		// The later segment's characters come first in the reversed output.
		for k := nseg - 1; k >= 0; k -= 1 {
			rev_comp(o, segs[k])
			o = o[len(segs[k]):]
		}
		o[0] = '\n'
	}
}

nthreads := 1
out: []u8
olen := 0

emit :: proc(r: Record) {
	nlines := (r.len + LINE - 1) / LINE
	dst := raw_data(out[olen:])
	per := max(64, (nlines + nthreads - 1) / nthreads)
	jobs := make([dynamic]Job, 0, nthreads, context.temp_allocator)
	for first := 0; first < nlines; first += per {
		append(&jobs, Job{r, dst, first, min(first + per, nlines)})
	}
	threads := make([]^thread.Thread, len(jobs), context.temp_allocator)
	for k in 1 ..< len(jobs) {
		threads[k] = thread.create_and_start_with_poly_data(&jobs[k], fill_lines)
	}
	fill_lines(&jobs[0])
	for k in 1 ..< len(jobs) {
		thread.join(threads[k])
		thread.destroy(threads[k])
	}
	free_all(context.temp_allocator)
	olen += r.len + nlines
}

put :: proc(data: []u8) {
	copy(out[olen:], data)
	olen += len(data)
}

// The record whose sequence lines are body (each ending in a newline but perhaps the last).
record :: proc(body: []u8, scratch: []u8) -> Record #no_bounds_check {
	n := len(body)
	if n > 0 && body[n - 1] == '\n' {
		n -= 1
	}
	lines := n / (LINE + 1) + 1
	full := n > 0
	for k := LINE; k < n; k += LINE + 1 {
		if body[k] != '\n' {
			full = false
			break
		}
	}
	if full && bytes.index_byte(body[(lines - 1) * (LINE + 1):n], '\n') < 0 {
		return Record{body[:n], n - (lines - 1), true}
	}
	m := 0
	for ch in body {
		if ch != '\n' {
			scratch[m] = ch
			m += 1
		}
	}
	return Record{scratch[:m], m, false}
}

main :: proc() {
	from := "ABCDGHKMNRSTVWY"
	to := "TVGHCDMKNYSABWR"
	for i in 0 ..< len(from) {
		xtab[from[i]] = to[i]
		xtab[from[i] + 32] = to[i]
	}
	for v in 0 ..< 65536 {
		pair[v] = u16(xtab[v >> 8]) | u16(xtab[v & 0xff]) << 8
	}
	nthreads = max(os.get_processor_core_count(), 1)

	input, err := os.read_entire_file(os.stdin, context.allocator)
	assert(err == nil)
	// The output is no longer than the input plus a newline per line and a final one.
	out = make([]u8, len(input) + len(input) / LINE + 2)
	scratch: []u8

	pos := 0
	for pos < len(input) {
		// A header line, then the sequence up to the next '>' at a line start.
		nl := bytes.index_byte(input[pos:], '\n')
		hend := len(input) if nl < 0 else pos + nl + 1
		put(input[pos:hend])
		bend := hend
		for bend < len(input) {
			gt := bytes.index_byte(input[bend:], '>')
			if gt < 0 {
				bend = len(input)
				break
			}
			bend += gt
			if input[bend - 1] == '\n' {
				break
			}
			bend += 1
		}
		if scratch == nil {
			scratch = make([]u8, len(input))
		}
		rec := record(input[hend:bend], scratch)
		if rec.len > 0 {
			emit(rec)
		}
		pos = bend
	}
	os.write(os.stdout, out[:olen])
}
