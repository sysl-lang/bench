// The Computer Language Benchmarks Game: reverse-complement. A port of the C program (Bob W's),
// written for this suite: each record is read a line at a time, complemented through a 256-entry
// table into the end of a buffer (so it is already reversed), then re-wrapped at 60 columns.
package main

import "core:bufio"
import "core:io"
import "core:os"

make_table :: proc() -> (t: [256]u8) {
	from := "ACGTMRWSYKVHDBN"
	to := "TGCAKYWSRMBDHVN"
	for i in 0 ..< len(from) {
		t[from[i]] = to[i]
		t[from[i] + 32] = to[i]
	}
	return
}

main :: proc() {
	xtab := make_table()

	r: bufio.Reader
	bufio.reader_init(&r, os.to_stream(os.stdin))
	defer bufio.reader_destroy(&r)
	out: bufio.Writer
	bufio.writer_init(&out, os.to_stream(os.stdout))
	defer bufio.writer_destroy(&out)
	w := bufio.writer_to_stream(&out)

	buf := make([dynamic]u8, 0, 1 << 20)
	defer delete(buf)

	header, err := bufio.reader_read_slice(&r, '\n')
	if len(header) == 0 || header[0] != '>' {
		os.exit(1)
	}
	header_copy := make([dynamic]u8)
	defer delete(header_copy)

	for len(header) > 0 {
		io.write(w, header)

		// Complemented bytes are appended in reading order and reversed once at the end.
		clear(&buf)
		next: []u8
		for {
			line, lerr := bufio.reader_read_slice(&r, '\n')
			if len(line) == 0 && lerr != nil {
				next = nil
				break
			}
			if line[0] == '>' {
				clear(&header_copy)
				append(&header_copy, ..line)
				next = header_copy[:]
				break
			}
			for c in line {
				if x := xtab[c]; x != 0 {
					append(&buf, x)
				}
			}
		}

		// Output from the end of buf, 60 to a line.
		pr := len(buf)
		out_line: [61]u8
		for pr > 0 {
			n := min(pr, 60)
			for k in 0 ..< n {
				out_line[k] = buf[pr - 1 - k]
			}
			out_line[n] = '\n'
			io.write(w, out_line[:n + 1])
			pr -= n
		}
		header = next
	}
	bufio.writer_flush(&out)
}
