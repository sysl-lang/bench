// Upstream C++ sieve.h: the flags are a fixed-size array on the stack, passed to `sieve` by value
// (C++ `std::array` by value; a Rust array is the same value type), its size a const generic as
// C++'s is a template parameter.

use crate::benchmark::Benchmark;

pub struct Sieve;

impl Sieve {
    fn sieve<const SIZE: usize>(&self, mut flags: [bool; SIZE], size: i32) -> i32 {
        let mut prime_count = 0;

        for i in 2..=size {
            if flags[(i - 1) as usize] {
                prime_count += 1;
                let mut k = i + i;
                while k <= size {
                    flags[(k - 1) as usize] = false;
                    k += i;
                }
            }
        }
        prime_count
    }
}

impl Benchmark for Sieve {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        const NUM_FLAGS: usize = 5000;
        let flags = [true; NUM_FLAGS];

        self.sieve(flags, 5000)
    }

    fn verify_result(&mut self, result: i32) -> bool {
        669 == result
    }
}
