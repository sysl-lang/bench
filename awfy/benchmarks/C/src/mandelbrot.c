#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "benchmark.h"

static bool verify(int32_t result, int32_t inner_iterations) {
  if (inner_iterations == 500) {
    return result == 191;
  }
  if (inner_iterations == 750) {
    return result == 50;
  }
  if (inner_iterations == 1) {
    return result == 128;
  }

  printf("No verification result for %d found\n", inner_iterations);
  printf("Result is: %d\n", result);
  return false;
}

static int32_t mandelbrot(int32_t size) {
  int32_t sum = 0;
  int32_t byte_acc = 0;
  int32_t bit_num = 0;

  int32_t y = 0;

  while (y < size) {
    const double ci = (2.0 * y / size) - 1.0;
    int32_t x = 0;

    while (x < size) {
      double zrzr = 0.0;
      double zi = 0.0;
      double zizi = 0.0;
      const double cr = (2.0 * x / size) - 1.5;

      int32_t z = 0;
      bool not_done = true;
      int32_t escape = 0;
      while (not_done && z < 50) {
        const double zr = zrzr - zizi + cr;
        zi = 2.0 * zr * zi + ci;

        // preserve recalculation
        zrzr = zr * zr;
        zizi = zi * zi;

        if (zrzr + zizi > 4.0) {
          not_done = false;
          escape = 1;
        }
        z += 1;
      }

      byte_acc = (byte_acc << 1) + escape;
      bit_num += 1;

      if (bit_num == 8) {
        sum ^= byte_acc;
        byte_acc = 0;
        bit_num = 0;
      } else if (x == size - 1) {
        byte_acc <<= (8 - bit_num);
        sum ^= byte_acc;
        byte_acc = 0;
        bit_num = 0;
      }
      x += 1;
    }
    y += 1;
  }
  return sum;
}

static Result Mandelbrot_benchmark(Benchmark* self) {
  (void)self;
  return (Result){.p = NULL};
}

static bool Mandelbrot_verify_result(Benchmark* self, Result result) {
  (void)self;
  (void)result;
  return false;
}

static bool Mandelbrot_inner_benchmark_loop(Benchmark* self,
                                            int32_t inner_iterations) {
  (void)self;
  return verify(mandelbrot(inner_iterations), inner_iterations);
}

static const BenchmarkVtbl Mandelbrot_vtbl = {
    Benchmark_destroy, Mandelbrot_benchmark, Mandelbrot_verify_result,
    Mandelbrot_inner_benchmark_loop};

Benchmark* Mandelbrot_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Mandelbrot_vtbl);
}
