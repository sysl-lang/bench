// The Computer Language Benchmarks Game: fannkuch-redux. Original, written for this benchmark: every
// permutation in the order the Game fixes, flipping until a 1 leads. It mirrors the Game's fastest C
// program that builds here (fannkuchredux.gcc-5, Jeremy Zerfas): the n! permutations are cut into
// blocks of consecutive indices shared out between threads, and a flip keeps the first value out of
// the array and reverses only the elements between. Here the blocks are smaller (720 per core) and
// taken from an atomic counter, where gcc-5 hands twelve blocks to OpenMP's static schedule, so the
// slower efficiency cores do not leave the others waiting. Bounds checks are off in the worker
// (#no_bounds_check), as C has none. A thread rebuilds the first permutation
// of its block from the block's index (in the factorial number system) and steps through the rest
// with the count array; a permutation's sign in the checksum is its index's parity. The per-thread
// checksums and maxima are combined at the end.
package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:sync"
import "core:thread"

MAX_N :: 16

n: int
fact: [MAX_N + 1]int
block_size, nblocks: int
next_block: int
total_checksum: int
total_max: int
result_mutex: sync.Mutex

worker :: proc() #no_bounds_check {
	p, pp: [MAX_N]u8
	count: [MAX_N]int
	checksum, max_flips := 0, 0

	for {
		block := sync.atomic_add(&next_block, 1)
		if block >= nblocks {
			break
		}
		first := block * block_size
		last := min(first + block_size, fact[n])

		// The permutation whose index is `first`.
		for i in 0 ..< n {
			p[i] = u8(i)
		}
		idx := first
		for i := n - 1; i > 0; i -= 1 {
			d := idx / fact[i]
			count[i] = d
			idx %= fact[i]
			for j in 0 ..= i {
				pp[j] = p[j]
			}
			for j in 0 ..= i {
				p[j] = pp[j + d] if j + d <= i else pp[j + d - i - 1]
			}
		}

		index := first
		for {
			if p[0] != 0 {
				pp = p
				// The first value is kept out of the array: each flip puts it at its own index and
				// reverses only the elements between.
				flips := 1
				f := int(p[0])
				for pp[f] != 0 {
					new_f := int(pp[f])
					pp[f] = u8(f)
					if f > 2 {
						lo, hi := 1, f - 1
						for lo < hi {
							pp[lo], pp[hi] = pp[hi], pp[lo]
							lo += 1
							hi -= 1
						}
					}
					f = new_f
					flips += 1
				}
				max_flips = max(max_flips, flips)
				checksum += flips if index % 2 == 0 else -flips
			}
			index += 1
			if index >= last {
				break
			}

			// The next permutation in the count-array order.
			head := p[1]
			p[1] = p[0]
			p[0] = head
			k := 1
			count[k] += 1
			for count[k] > k {
				count[k] = 0
				k += 1
				nxt := p[1]
				p[0] = nxt
				for j in 1 ..< k {
					p[j] = p[j + 1]
				}
				p[k] = head
				head = nxt
				count[k] += 1
			}
		}
	}
	sync.mutex_lock(&result_mutex)
	total_checksum += checksum
	total_max = max(total_max, max_flips)
	sync.mutex_unlock(&result_mutex)
}

main :: proc() {
	if len(os.args) < 2 {
		os.exit(1)
	}
	n, _ = strconv.parse_int(os.args[1])
	if n < 3 || n > 15 {
		os.exit(1)
	}
	fact[0] = 1
	for i in 1 ..= n {
		fact[i] = fact[i - 1] * i
	}

	nthreads := max(os.get_processor_core_count(), 1)
	nblocks = min(fact[n], 720 * nthreads)
	block_size = (fact[n] + nblocks - 1) / nblocks
	nblocks = (fact[n] + block_size - 1) / block_size

	threads := make([]^thread.Thread, nthreads - 1)
	for &t in threads {
		t = thread.create_and_start(worker)
	}
	worker()
	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}

	fmt.printf("%d\nPfannkuchen(%d) = %d\n", total_checksum, n, total_max)
}
