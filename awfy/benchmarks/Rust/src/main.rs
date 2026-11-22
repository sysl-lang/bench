// Upstream C++ harness.cpp and run.h: `harness <Benchmark> [num-iterations [inner-iter]]`, with
// upstream's output, which ReBench's RebenchLog adapter and scripts/run.zsh read.

mod benchmark;
mod memory;
mod som;

mod bounce;
mod cd;
mod deltablue;
mod havlak;
mod json;
mod json_data;
mod list;
mod mandelbrot;
mod nbody;
mod permute;
mod queens;
mod richards;
mod sieve;
mod storage;
mod towers;

use std::process::exit;
use std::time::Instant;

use benchmark::Runnable;

type BenchmarkSuiteCtr = fn() -> Box<dyn Runnable>;

struct Run {
    name: String,
    suite: BenchmarkSuiteCtr,
    num_iterations: i32,
    inner_iterations: i32,
    total: i64,
}

impl Run {
    fn new(name: String) -> Run {
        let suite = Run::select_benchmark(&name);
        Run { name, suite, num_iterations: 1, inner_iterations: 1, total: 0 }
    }

    fn run_benchmark(&mut self) {
        println!("Starting {} benchmark ...", self.name);
        let mut benchmark = (self.suite)();
        self.do_runs(benchmark.as_mut());
        drop(benchmark);

        self.report_benchmark();
        println!();
    }

    fn print_total(&self) {
        println!("Total Runtime: {}us", self.total);
    }

    fn set_num_iterations(&mut self, num_iterations: i32) {
        self.num_iterations = num_iterations;
    }

    fn set_inner_iterations(&mut self, inner_iterations: i32) {
        self.inner_iterations = inner_iterations;
    }

    fn select_benchmark(name: &str) -> BenchmarkSuiteCtr {
        match name {
            "Bounce" => || Box::new(bounce::Bounce),
            "CD" => || Box::new(cd::CD),
            "Havlak" => || Box::new(havlak::Havlak),
            "Json" => || Box::new(json::Json),
            "List" => || Box::new(list::List),
            "Mandelbrot" => || Box::new(mandelbrot::Mandelbrot),
            "NBody" => || Box::new(nbody::NBody),
            "Permute" => || Box::new(permute::Permute::new()),
            "Queens" => || Box::new(queens::Queens::new()),
            "Richards" => || Box::new(richards::Richards),
            "Sieve" => || Box::new(sieve::Sieve),
            "Storage" => || Box::new(storage::Storage::new()),
            "Towers" => || Box::new(towers::Towers::new()),
            "DeltaBlue" => || Box::new(deltablue::DeltaBlue),
            _ => {
                eprintln!("Benchmark not recognized: {name}");
                exit(1);
            }
        }
    }

    fn measure(&mut self, bench: &mut dyn Runnable) {
        let start_time = Instant::now();
        if !bench.inner_benchmark_loop(self.inner_iterations) {
            println!("Benchmark failed with incorrect result");
            exit(1);
        }
        let run_time = start_time.elapsed().as_micros() as i64;

        self.print_result(run_time);
        self.total += run_time;
    }

    fn do_runs(&mut self, bench: &mut dyn Runnable) {
        for _ in 0..self.num_iterations {
            self.measure(bench);
        }
    }

    fn report_benchmark(&self) {
        println!(
            "{}: iterations={} average: {}us total: {}us",
            self.name,
            self.num_iterations,
            self.total / i64::from(self.num_iterations),
            self.total
        );
    }

    fn print_result(&self, run_time: i64) {
        println!("{}: iterations=1 runtime: {}us", self.name, run_time);
    }
}

fn process_arguments(args: &[String]) -> Run {
    let mut run = Run::new(args[1].clone());

    if args.len() > 2 {
        run.set_num_iterations(args[2].parse().expect("num-iterations"));
        if args.len() > 3 {
            run.set_inner_iterations(args[3].parse().expect("inner-iter"));
        }
    }

    run
}

fn print_usage() {
    println!("./harness benchmark [num-iterations [inner-iter]]");
    println!();
    println!("  benchmark      - benchmark class name");
    println!("  num-iterations - number of times to execute benchmark, default: 1");
    println!("  inner-iter     - number of times the benchmark is executed in an inner loop,");
    println!("                   which is measured in total, default: 1");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        print_usage();
        exit(1);
    }

    let mut run = process_arguments(&args);
    run.run_benchmark();
    run.print_total();
}
