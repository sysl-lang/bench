// The Computer Language Benchmarks Game: mandelbrot. Original, written for this benchmark: the C
// program's per-pixel iteration (up to 50 iterations, escape when Tr + Ti > 4, coordinates
// 2*x/w - 1.5 and 2*y/h - 1.0, eight pixels to a byte). It mirrors the Game's fastest C program that
// builds here (mandelbrot.gcc-5, Ralph Ganszky and Dominic Letz: vector-extension pixels, the escape
// test every five iterations, rows spread over threads): the eight pixels of a byte are one
// #simd[8]f64, the x coordinates are computed once, and the rows are shared out between one thread
// per core through an atomic row counter. The image is assembled in memory and written in one call.
package main

import "core:fmt"
import "core:os"
import "core:simd"
import "core:strconv"
import "core:sync"
import "core:thread"

V :: #simd[8]f64

Image :: struct {
	w:         int,
	row_bytes: int,
	pixels:    []u8,
	xs:        []V,
	next_row:  int,
}

// One output byte: eight horizontally adjacent pixels iterated together, the escape test after every
// fifth iteration, as the C program makes it (all eight escaped ends the byte early; an escaped pixel
// only grows, or overflows to inf/NaN, which fail `<= 4` too).
byte_at :: #force_inline proc(cr, ci: V) -> u8 {
	zr, zi, tr, ti: V
	FOUR :: V(4.0)
	for _ in 0 ..< 10 {
		#unroll for _ in 0 ..< 5 {
			zi = (zr + zr) * zi + ci
			zr = tr - ti + cr
			tr = zr * zr
			ti = zi * zi
		}
		if simd.reduce_or(simd.lanes_le(tr + ti, FOUR)) == 0 {
			return 0
		}
	}
	BITS :: #simd[8]u64{0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01}
	mask := simd.lanes_le(tr + ti, FOUR)
	return u8(simd.reduce_or(mask & BITS))
}

render_row :: proc(img: ^Image, y: int) {
	wf := f64(img.w)
	ci := V(2.0 * f64(y) / wf - 1.0)
	row := img.pixels[y * img.row_bytes:][:img.row_bytes]
	#no_bounds_check for k in 0 ..< img.row_bytes {
		row[k] = byte_at(img.xs[k], ci)
	}
	// Pixels past the width in the last byte are zero bits, as the C program pads them.
	extra := img.row_bytes * 8 - img.w
	if extra != 0 {
		row[img.row_bytes - 1] &= u8(0xff) << uint(extra)
	}
}

worker :: proc(img: ^Image) {
	for {
		y := sync.atomic_add(&img.next_row, 1)
		if y >= img.w {
			return
		}
		render_row(img, y)
	}
}

main :: proc() {
	w, _ := strconv.parse_int(os.args[1])
	row_bytes := (w + 7) / 8
	xs := make([]V, row_bytes)
	for k in 0 ..< row_bytes {
		a: [8]f64
		for l in 0 ..< 8 {
			a[l] = 2.0 * f64(k * 8 + l) / f64(w) - 1.5
		}
		xs[k] = simd.from_array(a)
	}
	img := Image{w, row_bytes, make([]u8, row_bytes * w), xs, 0}

	n := max(os.get_processor_core_count(), 1)
	threads := make([]^thread.Thread, n - 1)
	for &t in threads {
		t = thread.create_and_start_with_poly_data(&img, worker)
	}
	worker(&img)
	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}

	header := fmt.tprintf("P4\n%d %d\n", w, w)
	os.write(os.stdout, transmute([]u8)header)
	os.write(os.stdout, img.pixels)
}
