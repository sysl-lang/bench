// harness.cpp and run.h of the C++ port: the entry point, which selects a
// benchmark by name, runs it num-iterations times, times each run with a
// monotonic clock, and prints upstream's lines.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "benchmark.h"

typedef Benchmark* (*BenchmarkSuiteCtr)(void);

typedef struct Run {
  const char* name;
  BenchmarkSuiteCtr suite;
  int32_t num_iterations;
  int32_t inner_iterations;
  int64_t total;
} Run;

static BenchmarkSuiteCtr select_benchmark(const char* name) {
  static const struct {
    const char* name;
    BenchmarkSuiteCtr ctr;
  } suites[] = {
      {"Bounce", Bounce_new},         {"CD", CD_new},
      {"Havlak", Havlak_new},         {"Json", Json_new},
      {"List", List_new},             {"Mandelbrot", Mandelbrot_new},
      {"NBody", NBody_new},           {"Permute", Permute_new},
      {"Queens", Queens_new},         {"Richards", Richards_new},
      {"Sieve", Sieve_new},           {"Storage", Storage_new},
      {"Towers", Towers_new},         {"DeltaBlue", DeltaBlue_new},
  };
  for (size_t i = 0; i < sizeof(suites) / sizeof(suites[0]); i += 1) {
    if (strcmp(name, suites[i].name) == 0) {
      return suites[i].ctr;
    }
  }
  fprintf(stderr, "Benchmark not recognized: %s\n", name);
  exit(1);
}

static int64_t now_us(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

static void print_result(const Run* run, int64_t run_time) {
  printf("%s: iterations=1 runtime: %lldus\n", run->name, (long long)run_time);
}

static void measure(Run* run, Benchmark* bench) {
  const int64_t start_time = now_us();
  if (!bench->vt->inner_benchmark_loop(bench, run->inner_iterations)) {
    printf("Benchmark failed with incorrect result\n");
    exit(1);
  }
  const int64_t end_time = now_us();
  const int64_t run_time = end_time - start_time;

  print_result(run, run_time);
  run->total += run_time;
}

static void do_runs(Run* run, Benchmark* bench) {
  for (int32_t i = 0; i < run->num_iterations; i += 1) {
    measure(run, bench);
  }
}

static void report_benchmark(const Run* run) {
  printf("%s: iterations=%d average: %lldus total: %lldus\n", run->name,
         run->num_iterations, (long long)(run->total / run->num_iterations),
         (long long)run->total);
}

static void run_benchmark(Run* run) {
  printf("Starting %s benchmark ...\n", run->name);
  Benchmark* benchmark = run->suite();
  do_runs(run, benchmark);
  benchmark->vt->destroy(benchmark);

  report_benchmark(run);
  printf("\n");
}

static void print_usage(void) {
  printf("./harness benchmark [num-iterations [inner-iter]]\n");
  printf("\n");
  printf("  benchmark      - benchmark class name\n");
  printf("  num-iterations - number of times to execute benchmark, default: 1\n");
  printf("  inner-iter     - number of times the benchmark is executed in an inner loop,\n");
  printf("                   which is measured in total, default: 1\n");
}

int main(int argc, const char* argv[]) {
  if (argc < 2) {
    print_usage();
    return 1;
  }

  Run run = {argv[1], select_benchmark(argv[1]), 1, 1, 0};
  if (argc > 2) {
    run.num_iterations = (int32_t)strtol(argv[2], NULL, 10);
    if (argc > 3) {
      run.inner_iterations = (int32_t)strtol(argv[3], NULL, 10);
    }
  }

  run_benchmark(&run);
  printf("Total Runtime: %lldus\n", (long long)run.total);
  return 0;
}
