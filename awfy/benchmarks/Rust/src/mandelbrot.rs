// Upstream C++ mandelbrot.h.

use crate::benchmark::Benchmark;

pub struct Mandelbrot;

impl Benchmark for Mandelbrot {
    type Result = ();

    fn benchmark(&mut self) {
        unreachable!("Should never be reached");
    }

    fn verify_result(&mut self, _result: ()) -> bool {
        false
    }

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        self.verify(self.mandelbrot(inner_iterations), inner_iterations)
    }
}

impl Mandelbrot {
    fn verify(&self, result: i32, inner_iterations: i32) -> bool {
        if inner_iterations == 500 {
            return result == 191;
        }
        if inner_iterations == 750 {
            return result == 50;
        }
        if inner_iterations == 1 {
            return result == 128;
        }

        println!("No verification result for {inner_iterations} found");
        println!("Result is: {result}");
        false
    }

    fn mandelbrot(&self, size: i32) -> i32 {
        let mut sum = 0;
        let mut byte_acc = 0;
        let mut bit_num = 0;

        let mut y = 0;

        while y < size {
            let ci = (2.0 * f64::from(y) / f64::from(size)) - 1.0;
            let mut x = 0;

            while x < size {
                let mut zrzr = 0.0;
                let mut zi = 0.0;
                let mut zizi = 0.0;
                let cr = (2.0 * f64::from(x) / f64::from(size)) - 1.5;

                let mut z = 0;
                let mut not_done = true;
                let mut escape = 0;
                while not_done && z < 50 {
                    let zr = zrzr - zizi + cr;
                    zi = 2.0 * zr * zi + ci;

                    // preserve recalculation
                    zrzr = zr * zr;
                    zizi = zi * zi;

                    if zrzr + zizi > 4.0 {
                        not_done = false;
                        escape = 1;
                    }
                    z += 1;
                }

                byte_acc = (byte_acc << 1) + escape;
                bit_num += 1;

                // Code is very similar for these cases, but using separate blocks
                // ensures we skip the shifting when it's unnecessary, which is most
                // cases.
                if bit_num == 8 {
                    sum ^= byte_acc;
                    byte_acc = 0;
                    bit_num = 0;
                } else if x == size - 1 {
                    byte_acc <<= 8 - bit_num;
                    sum ^= byte_acc;
                    byte_acc = 0;
                    bit_num = 0;
                }
                x += 1;
            }
            y += 1;
        }
        sum
    }
}
