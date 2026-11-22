#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"
#include "som/random.h"

typedef struct Ball {
  int32_t x;
  int32_t y;
  int32_t x_vel;
  int32_t y_vel;
} Ball;

static Ball Ball_make(Random* random) {
  Ball b;
  b.x = Random_next(random) % 500;
  b.y = Random_next(random) % 500;
  b.x_vel = (Random_next(random) % 300) - 150;
  b.y_vel = (Random_next(random) % 300) - 150;
  return b;
}

static bool Ball_bounce(Ball* self) {
  const int32_t x_limit = 500;
  const int32_t y_limit = 500;
  bool bounced = false;

  self->x += self->x_vel;
  self->y += self->y_vel;
  if (self->x > x_limit) {
    self->x = x_limit;
    self->x_vel = 0 - abs(self->x_vel);
    bounced = true;
  }
  if (self->x < 0) {
    self->x = 0;
    self->x_vel = abs(self->x_vel);
    bounced = true;
  }
  if (self->y > y_limit) {
    self->y = y_limit;
    self->y_vel = 0 - abs(self->y_vel);
    bounced = true;
  }
  if (self->y < 0) {
    self->y = 0;
    self->y_vel = abs(self->y_vel);
    bounced = true;
  }
  return bounced;
}

static Result Bounce_benchmark(Benchmark* self) {
  (void)self;
  Random random = Random_make();

  enum { ball_count = 100 };
  int32_t bounces = 0;

  Ball balls[ball_count] = {0};

  for (int32_t i = 0; i < ball_count; i += 1) {
    balls[i] = Ball_make(&random);
  }

  for (int32_t j = 0; j < 50; j += 1) {
    for (int32_t i = 0; i < ball_count; i += 1) {
      if (Ball_bounce(&balls[i])) {
        bounces += 1;
      }
    }
  }
  return (Result){.i = bounces};
}

static bool Bounce_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 1331 == result.i;
}

static const BenchmarkVtbl Bounce_vtbl = {
    Benchmark_destroy, Bounce_benchmark, Bounce_verify_result,
    Benchmark_inner_benchmark_loop};

Benchmark* Bounce_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Bounce_vtbl);
}
