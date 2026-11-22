#include <stdbool.h>
#include <stdint.h>

#include "benchmark.h"

enum { NUM_FLAGS = 5000 };

// std::array<bool, 5000>: a fixed-size array that is a value. The C++ sieve()
// takes it by value, so the C one takes the struct by value.
typedef struct Flags {
  bool flags[NUM_FLAGS];
} Flags;

static int32_t sieve(Flags flags, int32_t size) {
  int32_t prime_count = 0;

  for (int32_t i = 2; i <= size; i += 1) {
    if (flags.flags[i - 1]) {
      prime_count += 1;
      int32_t k = i + i;
      while (k <= size) {
        flags.flags[k - 1] = false;
        k += i;
      }
    }
  }
  return prime_count;
}

static Result Sieve_benchmark(Benchmark* self) {
  (void)self;
  Flags flags = {{0}};
  for (int32_t i = 0; i < NUM_FLAGS; i += 1) {
    flags.flags[i] = true;
  }
  return (Result){.i = sieve(flags, 5000)};
}

static bool Sieve_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 669 == result.i;
}

static const BenchmarkVtbl Sieve_vtbl = {Benchmark_destroy, Sieve_benchmark,
                                         Sieve_verify_result,
                                         Benchmark_inner_benchmark_loop};

Benchmark* Sieve_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Sieve_vtbl);
}
