// The Computer Language Benchmarks Game: pidigits. Original, written for this benchmark. It mirrors
// the Game's fastest C program (pidigits.gcc-2, Michael Ganss, Oleksii Prudkyi and Craig Russell, from
// Mike Pall and Wim Couwenberg's pidigits.lua-5), which is single-threaded: the spigot kept as two
// numerators n1, n2 and a denominator d; a digit is emitted when n1/d and n2/d agree, otherwise the
// next term is produced. GMP through a foreign import of gmp.h's __gmpz_* symbols; output gathered in
// a buffered writer.
package main

import "core:bufio"
import "core:c"
import "core:io"
import "core:os"
import "core:strconv"

foreign import gmp "system:gmp"

Mpz :: struct {
	alloc: c.int,
	size:  c.int,
	d:     rawptr,
}

@(default_calling_convention = "c")
foreign gmp {
	__gmpz_init :: proc(x: ^Mpz) ---
	__gmpz_init_set_si :: proc(x: ^Mpz, v: c.long) ---
	__gmpz_add :: proc(r, a, b: ^Mpz) ---
	__gmpz_mul :: proc(r, a, b: ^Mpz) ---
	__gmpz_mul_si :: proc(r, a: ^Mpz, b: c.long) ---
	__gmpz_tdiv_q :: proc(q, n, d: ^Mpz) ---
	__gmpz_get_si :: proc(x: ^Mpz) -> c.long ---
	__gmpz_cmp :: proc(a, b: ^Mpz) -> c.int ---
}

n1, n2, d, u, v, w: Mpz

main :: proc() {
	n, _ := strconv.parse_int(os.args[1])

	out: bufio.Writer
	bufio.writer_init(&out, os.to_stream(os.stdout))
	defer bufio.writer_destroy(&out)
	stream := bufio.writer_to_stream(&out)

	__gmpz_init(&u)
	__gmpz_init(&v)
	__gmpz_init_set_si(&w, 0)
	__gmpz_init_set_si(&n1, 4)
	__gmpz_init_set_si(&n2, 3)
	__gmpz_init_set_si(&d, 1)

	k: c.long = 1
	i := 0
	buf: [32]u8
	for {
		__gmpz_tdiv_q(&u, &n1, &d)
		__gmpz_tdiv_q(&v, &n2, &d)
		if __gmpz_cmp(&u, &v) == 0 {
			io.write_byte(stream, u8('0' + __gmpz_get_si(&u)))
			i += 1
			if i % 10 == 0 {
				io.write_string(stream, "\t:")
				io.write_string(stream, strconv.write_int(buf[:], i64(i), 10))
				io.write_byte(stream, '\n')
			}
			if i == n {
				break
			}
			// extract
			__gmpz_mul_si(&u, &u, -10)
			__gmpz_mul(&u, &d, &u)
			__gmpz_mul_si(&n1, &n1, 10)
			__gmpz_add(&n1, &n1, &u)
			__gmpz_mul_si(&n2, &n2, 10)
			__gmpz_add(&n2, &n2, &u)
		} else {
			// produce
			k2 := k * 2
			__gmpz_mul_si(&u, &n1, k2 - 1)
			__gmpz_add(&v, &n2, &n2)
			__gmpz_mul_si(&w, &n1, k - 1)
			__gmpz_add(&n1, &u, &v)
			__gmpz_mul_si(&u, &n2, k + 2)
			__gmpz_add(&n2, &w, &u)
			__gmpz_mul_si(&d, &d, k2 + 1)
			k += 1
		}
	}
	if i % 10 != 0 {
		for _ in 0 ..< 10 - n % 10 {
			io.write_byte(stream, ' ')
		}
		io.write_string(stream, "\t:")
		io.write_string(stream, strconv.write_int(buf[:], i64(n), 10))
		io.write_byte(stream, '\n')
	}
	bufio.writer_flush(&out)
}
