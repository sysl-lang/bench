#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"

typedef struct Queens {
  Benchmark base;
  bool* free_maxs;
  bool* free_rows;
  bool* free_mins;
  int32_t* queen_rows;
} Queens;

static bool get_row_column(const Queens* self, int32_t r, int32_t c) {
  return self->free_rows[r] && self->free_maxs[c + r] &&
         self->free_mins[c - r + 7];
}

static void set_row_column(Queens* self, int32_t r, int32_t c, bool v) {
  self->free_rows[r] = v;
  self->free_maxs[c + r] = v;
  self->free_mins[c - r + 7] = v;
}

static bool place_queen(Queens* self, int32_t c) {
  for (int32_t r = 0; r < 8; r += 1) {
    if (get_row_column(self, r, c)) {
      self->queen_rows[r] = c;
      set_row_column(self, r, c, false);

      if (c == 7) {
        return true;
      }

      if (place_queen(self, c + 1)) {
        return true;
      }
      set_row_column(self, r, c, true);
    }
  }
  return false;
}

static bool queens(Queens* self) {
  self->free_rows = (bool*)malloc(8 * sizeof(bool));
  for (int32_t i = 0; i < 8; i += 1) {
    self->free_rows[i] = true;
  }
  self->free_maxs = (bool*)malloc(16 * sizeof(bool));
  for (int32_t i = 0; i < 16; i += 1) {
    self->free_maxs[i] = true;
  }
  self->free_mins = (bool*)malloc(16 * sizeof(bool));
  for (int32_t i = 0; i < 16; i += 1) {
    self->free_mins[i] = true;
  }
  self->queen_rows = (int32_t*)malloc(8 * sizeof(int32_t));
  for (int32_t i = 0; i < 8; i += 1) {
    self->queen_rows[i] = -1;
  }

  const bool result = place_queen(self, 0);

  free(self->free_rows);
  free(self->free_maxs);
  free(self->free_mins);
  free(self->queen_rows);

  return result;
}

static Result Queens_benchmark(Benchmark* base) {
  Queens* self = (Queens*)base;
  bool result = true;
  for (int32_t i = 0; i < 10; i += 1) {
    result = result && queens(self);
  }
  return (Result){.b = result};
}

static bool Queens_verify_result(Benchmark* self, Result result) {
  (void)self;
  return result.b;
}

static const BenchmarkVtbl Queens_vtbl = {Benchmark_destroy, Queens_benchmark,
                                          Queens_verify_result,
                                          Benchmark_inner_benchmark_loop};

Benchmark* Queens_new(void) {
  Queens* q = (Queens*)Benchmark_alloc(sizeof(Queens), &Queens_vtbl);
  q->free_maxs = NULL;
  q->free_rows = NULL;
  q->free_mins = NULL;
  q->queen_rows = NULL;
  return &q->base;
}
