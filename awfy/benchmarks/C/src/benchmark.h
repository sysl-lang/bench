#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

// What benchmark() hands to verify_result(). The C++ port boxes it in a
// std::any; C has no such type, so each benchmark reads back the member it
// wrote.
typedef union Result {
  int32_t i;
  bool b;
  const void* p;
} Result;

typedef struct Benchmark Benchmark;

typedef struct BenchmarkVtbl {
  void (*destroy)(Benchmark* self);
  Result (*benchmark)(Benchmark* self);
  bool (*verify_result)(Benchmark* self, Result result);
  bool (*inner_benchmark_loop)(Benchmark* self, int32_t inner_iterations);
} BenchmarkVtbl;

struct Benchmark {
  const BenchmarkVtbl* vt;
};

// The base class's inner_benchmark_loop.
static inline bool Benchmark_inner_benchmark_loop(Benchmark* self,
                                                  int32_t inner_iterations) {
  for (int32_t i = 0; i < inner_iterations; i += 1) {
    if (!self->vt->verify_result(self, self->vt->benchmark(self))) {
      return false;
    }
  }
  return true;
}

// The base class's (defaulted, virtual) destructor.
static inline void Benchmark_destroy(Benchmark* self) {
  free(self);
}

// Constructors, one per benchmark; each returns a malloc'd object.
Benchmark* Bounce_new(void);
Benchmark* CD_new(void);
Benchmark* DeltaBlue_new(void);
Benchmark* Havlak_new(void);
Benchmark* Json_new(void);
Benchmark* List_new(void);
Benchmark* Mandelbrot_new(void);
Benchmark* NBody_new(void);
Benchmark* Permute_new(void);
Benchmark* Queens_new(void);
Benchmark* Richards_new(void);
Benchmark* Sieve_new(void);
Benchmark* Storage_new(void);
Benchmark* Towers_new(void);

// Builds a benchmark object with the given vtable: `new X()`.
static inline Benchmark* Benchmark_alloc(size_t size, const BenchmarkVtbl* vt) {
  Benchmark* b = (Benchmark*)malloc(size);
  b->vt = vt;
  return b;
}
