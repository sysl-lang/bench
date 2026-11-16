// The Computer Language Benchmarks Game: mandelbrot. A port of the C program (Greg Buchholz's),
// written for this suite: up to 50 iterations per pixel, eight pixels packed into each output byte.
package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"

main :: proc() {
	w, _ := strconv.parse_int(os.args[1])
	h := w
	bit_num := 0
	byte_acc: u8 = 0
	ITER :: 50
	LIMIT :: 2.0

	out: bufio.Writer
	bufio.writer_init(&out, os.to_stream(os.stdout))
	defer bufio.writer_destroy(&out)
	stream := bufio.writer_to_stream(&out)

	fmt.wprintf(stream, "P4\n%d %d\n", w, h)

	for yi in 0 ..< h {
		y := f64(yi)
		for xi in 0 ..< w {
			x := f64(xi)
			zr, zi, tr, ti := 0.0, 0.0, 0.0, 0.0
			cr := 2.0 * x / f64(w) - 1.5
			ci := 2.0 * y / f64(h) - 1.0

			for i := 0; i < ITER && (tr + ti <= LIMIT * LIMIT); i += 1 {
				zi = 2.0 * zr * zi + ci
				zr = tr - ti + cr
				tr = zr * zr
				ti = zi * zi
			}

			byte_acc <<= 1
			if tr + ti <= LIMIT * LIMIT {
				byte_acc |= 0x01
			}

			bit_num += 1

			if bit_num == 8 {
				io.write_byte(stream, byte_acc)
				byte_acc = 0
				bit_num = 0
			} else if xi == w - 1 {
				byte_acc <<= uint(8 - w % 8)
				io.write_byte(stream, byte_acc)
				byte_acc = 0
				bit_num = 0
			}
		}
	}
	bufio.writer_flush(&out)
}
