// The Computer Language Benchmarks Game: fannkuch-redux. A port of the C program (Ledrug Katz's),
// written for this suite: Tompkin-Paige iterative permutation generation, flipping until a 1 leads.
package main

import "core:fmt"
import "core:os"
import "core:strconv"

s, t: [16]i32
max_flips: i32 = 0
max_n: int
odd: i32 = 0
checksum: i32 = 0

flip :: proc() -> i32 {
	for i in 0 ..< max_n {
		t[i] = s[i]
	}
	i: i32 = 1
	for {
		x, y := 0, int(t[0])
		for x < y {
			c := t[x]
			t[x] = t[y]
			t[y] = c
			x += 1
			y -= 1
		}
		i += 1
		if t[t[0]] == 0 {
			break
		}
	}
	return i
}

rotate :: proc(n: int) {
	c := s[0]
	for i in 1 ..= n {
		s[i - 1] = s[i]
	}
	s[n] = c
}

// Tompkin-Paige iterative perm generation
tk :: proc(n: int) {
	i := 0
	c: [16]i32

	for i < n {
		rotate(i)
		if int(c[i]) >= i {
			c[i] = 0
			i += 1
			continue
		}

		c[i] += 1
		i = 1
		odd = ~odd
		if s[0] != 0 {
			f: i32 = 1
			if s[s[0]] != 0 {
				f = flip()
			}
			if f > max_flips {
				max_flips = f
			}
			checksum += -f if odd != 0 else f
		}
	}
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintfln("usage: %s number", os.args[0])
		os.exit(1)
	}

	max_n, _ = strconv.parse_int(os.args[1])
	if max_n < 3 || max_n > 15 {
		fmt.eprintln("range: must be 3 <= n <= 12")
		os.exit(1)
	}

	for i in 0 ..< max_n {
		s[i] = i32(i)
	}
	tk(max_n)

	fmt.printf("%d\nPfannkuchen(%d) = %d\n", checksum, max_n, max_flips)
}
