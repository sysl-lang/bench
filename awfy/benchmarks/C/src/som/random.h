#pragma once

#include <stdint.h>

typedef struct Random {
  int32_t seed;
} Random;

static inline Random Random_make(void) {
  return (Random){74755};
}

static inline int32_t Random_next(Random* self) {
  self->seed = ((self->seed * 1309) + 13849) & 65535;
  return self->seed;
}
