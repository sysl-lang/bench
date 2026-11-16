// The Computer Language Benchmarks Game: spectral-norm. A port of the C program (Sebastien
// Loisel's), written for this suite: A is computed on the fly, ten rounds of A then A transposed.
package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"

eval_a :: #force_inline proc(i, j: int) -> f64 {
	return 1.0 / f64((i + j) * (i + j + 1) / 2 + i + 1)
}

eval_a_times_u :: proc(u, au: []f64) {
	for i in 0 ..< len(u) {
		au[i] = 0
		for j in 0 ..< len(u) {
			au[i] += eval_a(i, j) * u[j]
		}
	}
}

eval_at_times_u :: proc(u, au: []f64) {
	for i in 0 ..< len(u) {
		au[i] = 0
		for j in 0 ..< len(u) {
			au[i] += eval_a(j, i) * u[j]
		}
	}
}

eval_at_a_times_u :: proc(u, atau, v: []f64) {
	eval_a_times_u(u, v)
	eval_at_times_u(v, atau)
}

main :: proc() {
	n := 100
	if len(os.args) == 2 {
		n, _ = strconv.parse_int(os.args[1])
	}
	u := make([]f64, n)
	v := make([]f64, n)
	w := make([]f64, n)
	for i in 0 ..< n {
		u[i] = 1
	}
	for _ in 0 ..< 10 {
		eval_at_a_times_u(u, v, w)
		eval_at_a_times_u(v, u, w)
	}
	vbv, vv := 0.0, 0.0
	for i in 0 ..< n {
		vbv += u[i] * v[i]
		vv += v[i] * v[i]
	}
	fmt.printf("%0.9f\n", math.sqrt(vbv / vv))
}
