#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"

typedef struct Permute {
  Benchmark base;
  int32_t count;
  int32_t* v;
} Permute;

static void Permute_swap(Permute* self, int32_t i, int32_t j) {
  const int32_t tmp = self->v[i];
  self->v[i] = self->v[j];
  self->v[j] = tmp;
}

static void Permute_permute(Permute* self, int32_t n) {
  self->count += 1;
  if (n != 0) {
    const int32_t n1 = n - 1;
    Permute_permute(self, n1);
    for (int32_t i = n1; i >= 0; i -= 1) {
      Permute_swap(self, n1, i);
      Permute_permute(self, n1);
      Permute_swap(self, n1, i);
    }
  }
}

static Result Permute_benchmark(Benchmark* base) {
  Permute* self = (Permute*)base;
  self->count = 0;
  self->v = (int32_t*)malloc(6 * sizeof(int32_t));
  Permute_permute(self, 6);
  free(self->v);
  return (Result){.i = self->count};
}

static bool Permute_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 8660 == result.i;
}

static const BenchmarkVtbl Permute_vtbl = {
    Benchmark_destroy, Permute_benchmark, Permute_verify_result,
    Benchmark_inner_benchmark_loop};

Benchmark* Permute_new(void) {
  Permute* p = (Permute*)Benchmark_alloc(sizeof(Permute), &Permute_vtbl);
  p->count = 0;
  p->v = NULL;
  return &p->base;
}
