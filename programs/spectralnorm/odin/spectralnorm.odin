// The Computer Language Benchmarks Game: spectral-norm. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (spectralnorm.gcc-3, Mr Ledrug): ten rounds of
// A then A transposed applied to a vector, each term u[j] / A's integer denominator, computed on the
// fly; each product's rows split into one contiguous range per core, as its `omp parallel for` splits
// them. Bounds checks are off in the inner loops (#no_bounds_check), as C has none. Each row is summed in the C program's order, so the result does not
// depend on the thread count.
package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:thread"

// The denominator of A(i, j) = 1 / ((i + j)(i + j + 1)/2 + i + 1), an int, as the C program has it.
a :: #force_inline proc(i, j: int) -> f64 {
	return f64((i + j) * (i + j + 1) / 2 + i + 1)
}

Job :: struct {
	u, au:       []f64,
	first, last: int,
	transpose:   bool,
}

rows :: proc(job: ^Job) #no_bounds_check {
	u := job.u
	for i in job.first ..< job.last {
		sum := 0.0
		if job.transpose {
			for j in 0 ..< len(u) {
				sum += u[j] / a(j, i)
			}
		} else {
			for j in 0 ..< len(u) {
				sum += u[j] / a(i, j)
			}
		}
		job.au[i] = sum
	}
}

nthreads := 1

parallel :: proc(u, au: []f64, transpose: bool) {
	n := len(au)
	per := (n + nthreads - 1) / nthreads
	jobs := make([]Job, nthreads, context.temp_allocator)
	threads := make([]^thread.Thread, nthreads, context.temp_allocator)
	count := 0
	for first := 0; first < n; first += per {
		jobs[count] = Job{u, au, first, min(first + per, n), transpose}
		count += 1
	}
	for k in 1 ..< count {
		threads[k] = thread.create_and_start_with_poly_data(&jobs[k], rows)
	}
	rows(&jobs[0])
	for k in 1 ..< count {
		thread.join(threads[k])
		thread.destroy(threads[k])
	}
	free_all(context.temp_allocator)
}

eval_at_a_times_u :: proc(u, atau, v: []f64) {
	parallel(u, v, false)
	parallel(v, atau, true)
}

main :: proc() {
	n := 100
	if len(os.args) == 2 {
		n, _ = strconv.parse_int(os.args[1])
	}
	nthreads = max(os.get_processor_core_count(), 1)
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
