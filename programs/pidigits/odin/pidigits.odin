// The Computer Language Benchmarks Game: pidigits. A port of the C program (Mr Ledrug's), written
// for this suite: Gibbons' spigot over GMP through a foreign import of gmp.h's __gmpz_* symbols,
// output through a buffered writer.
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
	__gmpz_init_set_ui :: proc(x: ^Mpz, v: c.ulong) ---
	__gmpz_add :: proc(r, a, b: ^Mpz) ---
	__gmpz_mul_ui :: proc(r, a: ^Mpz, b: c.ulong) ---
	__gmpz_addmul_ui :: proc(r, a: ^Mpz, b: c.ulong) ---
	__gmpz_submul_ui :: proc(r, a: ^Mpz, b: c.ulong) ---
	__gmpz_tdiv_q :: proc(q, n, d: ^Mpz) ---
	__gmpz_get_ui :: proc(x: ^Mpz) -> c.ulong ---
	__gmpz_cmp :: proc(a, b: ^Mpz) -> c.int ---
}

tmp1, tmp2, acc, den, num: Mpz

extract_digit :: proc(nth: c.ulong) -> c.ulong {
	// joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
	__gmpz_mul_ui(&tmp1, &num, nth)
	__gmpz_add(&tmp2, &tmp1, &acc)
	__gmpz_tdiv_q(&tmp1, &tmp2, &den)
	return __gmpz_get_ui(&tmp1)
}

eliminate_digit :: proc(d: c.ulong) {
	__gmpz_submul_ui(&acc, &den, d)
	__gmpz_mul_ui(&acc, &acc, 10)
	__gmpz_mul_ui(&num, &num, 10)
}

next_term :: proc(k: c.ulong) {
	k2 := k * 2 + 1
	__gmpz_addmul_ui(&acc, &num, 2)
	__gmpz_mul_ui(&acc, &acc, k2)
	__gmpz_mul_ui(&den, &den, k2)
	__gmpz_mul_ui(&num, &num, k)
}

main :: proc() {
	n := 27
	if len(os.args) > 1 {
		n, _ = strconv.parse_int(os.args[1])
	}

	out: bufio.Writer
	bufio.writer_init(&out, os.to_stream(os.stdout))
	defer bufio.writer_destroy(&out)
	w := bufio.writer_to_stream(&out)

	__gmpz_init(&tmp1)
	__gmpz_init(&tmp2)
	__gmpz_init_set_ui(&acc, 0)
	__gmpz_init_set_ui(&den, 1)
	__gmpz_init_set_ui(&num, 1)

	i := 0
	k: c.ulong = 0
	for i < n {
		k += 1
		next_term(k)
		if __gmpz_cmp(&num, &acc) > 0 do continue

		d := extract_digit(3)
		if d != extract_digit(4) do continue

		io.write_byte(w, u8('0' + d))
		i += 1
		if i % 10 == 0 {
			io.write_string(w, "\t:")
			io.write_int(w, i)
			io.write_byte(w, '\n')
		}
		eliminate_digit(d)
	}

	if n % 10 != 0 {
		for _ in 0 ..< 10 - n % 10 do io.write_byte(w, ' ')
		io.write_string(w, "\t:")
		io.write_int(w, n)
		io.write_byte(w, '\n')
	}
	bufio.writer_flush(&out)
}
