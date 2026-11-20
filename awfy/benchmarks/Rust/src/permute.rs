// Upstream C++ permute.h. The array is a field allocated and freed on every iteration, as C++'s
// `new int32_t[6]` / `delete[]` is.

use crate::benchmark::Benchmark;

pub struct Permute {
    count: i32,
    v: Box<[i32]>,
}

impl Permute {
    pub fn new() -> Permute {
        Permute { count: 0, v: Box::default() }
    }

    fn permute(&mut self, n: i32) {
        self.count += 1;
        if n != 0 {
            let n1 = n - 1;
            self.permute(n1);
            for i in (0..=n1).rev() {
                self.swap(n1, i);
                self.permute(n1);
                self.swap(n1, i);
            }
        }
    }

    fn swap(&mut self, i: i32, j: i32) {
        self.v.swap(i as usize, j as usize);
    }
}

impl Benchmark for Permute {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        self.count = 0;
        self.v = vec![0; 6].into_boxed_slice();
        self.permute(6);
        self.v = Box::default();
        self.count
    }

    fn verify_result(&mut self, result: i32) -> bool {
        8660 == result
    }
}
