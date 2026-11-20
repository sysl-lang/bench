// Upstream C++ benchmark.h. C++ returns a type-erased `std::any` from `benchmark()` (Java's
// `Object`); Rust states the result's type as an associated type, so `verify_result` takes it
// without a cast. The harness selects a benchmark at run time through the object-safe `Runnable`,
// one dynamic call per `inner_benchmark_loop`, as C++'s virtual call is.

pub trait Benchmark {
    type Result;

    fn benchmark(&mut self) -> Self::Result;
    fn verify_result(&mut self, result: Self::Result) -> bool;

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        for _ in 0..inner_iterations {
            let result = self.benchmark();
            if !self.verify_result(result) {
                return false;
            }
        }
        true
    }
}

pub trait Runnable {
    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool;
}

impl<B: Benchmark> Runnable for B {
    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        Benchmark::inner_benchmark_loop(self, inner_iterations)
    }
}
