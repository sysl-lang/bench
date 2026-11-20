#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "benchmark.h"
#include "som/error.h"

#define PI 3.141592653589793
#define SOLAR_MASS (4 * PI * PI)
#define DAYS_PER_YER 365.24

typedef struct Body {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double mass;
} Body;

static Body Body_make(double x, double y, double z, double vx, double vy,
                      double vz, double mass) {
  return (Body){x,
                y,
                z,
                vx * DAYS_PER_YER,
                vy * DAYS_PER_YER,
                vz * DAYS_PER_YER,
                mass * SOLAR_MASS};
}

static void Body_offset_momentum(Body* self, double px, double py, double pz) {
  self->vx = 0.0 - (px / SOLAR_MASS);
  self->vy = 0.0 - (py / SOLAR_MASS);
  self->vz = 0.0 - (pz / SOLAR_MASS);
}

static Body Body_jupiter(void) {
  return Body_make(4.84143144246472090e+00, -1.16032004402742839e+00,
                   -1.03622044471123109e-01, 1.66007664274403694e-03,
                   7.69901118419740425e-03, -6.90460016972063023e-05,
                   9.54791938424326609e-04);
}

static Body Body_saturn(void) {
  return Body_make(8.34336671824457987e+00, 4.12479856412430479e+00,
                   -4.03523417114321381e-01, -2.76742510726862411e-03,
                   4.99852801234917238e-03, 2.30417297573763929e-05,
                   2.85885980666130812e-04);
}

static Body Body_uranus(void) {
  return Body_make(1.28943695621391310e+01, -1.51111514016986312e+01,
                   -2.23307578892655734e-01, 2.96460137564761618e-03,
                   2.37847173959480950e-03, -2.96589568540237556e-05,
                   4.36624404335156298e-05);
}

static Body Body_neptune(void) {
  return Body_make(1.53796971148509165e+01, -2.59193146099879641e+01,
                   1.79258772950371181e-01, 2.68067772490389322e-03,
                   1.62824170038242295e-03, -9.51592254519715870e-05,
                   5.15138902046611451e-05);
}

static Body Body_sun(void) {
  return Body_make(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
}

typedef struct NBodySystem {
  int32_t bodies_size;
  Body bodies[5];
} NBodySystem;

static void NBodySystem_init(NBodySystem* self) {
  self->bodies_size = 5;
  Body* bodies = self->bodies;
  bodies[0] = Body_sun();
  bodies[1] = Body_jupiter();
  bodies[2] = Body_saturn();
  bodies[3] = Body_uranus();
  bodies[4] = Body_neptune();

  double px = 0.0;
  double py = 0.0;
  double pz = 0.0;

  for (int32_t i = 0; i < self->bodies_size; i += 1) {
    px += bodies[i].vx * bodies[i].mass;
    py += bodies[i].vy * bodies[i].mass;
    pz += bodies[i].vz * bodies[i].mass;
  }

  Body_offset_momentum(&bodies[0], px, py, pz);
}

static void NBodySystem_advance(NBodySystem* self, double dt) {
  for (int32_t i = 0; i < self->bodies_size; i += 1) {
    Body* i_body = &self->bodies[i];

    for (int32_t j = i + 1; j < self->bodies_size; j += 1) {
      Body* j_body = &self->bodies[j];
      const double dx = i_body->x - j_body->x;
      const double dy = i_body->y - j_body->y;
      const double dz = i_body->z - j_body->z;

      const double d_squared = dx * dx + dy * dy + dz * dz;
      const double distance = sqrt(d_squared);
      const double mag = dt / (d_squared * distance);

      i_body->vx = i_body->vx - (dx * j_body->mass * mag);
      i_body->vy = i_body->vy - (dy * j_body->mass * mag);
      i_body->vz = i_body->vz - (dz * j_body->mass * mag);

      j_body->vx = j_body->vx + (dx * i_body->mass * mag);
      j_body->vy = j_body->vy + (dy * i_body->mass * mag);
      j_body->vz = j_body->vz + (dz * i_body->mass * mag);
    }
  }

  for (int32_t i = 0; i < self->bodies_size; i += 1) {
    Body* b = &self->bodies[i];
    b->x = b->x + dt * b->vx;
    b->y = b->y + dt * b->vy;
    b->z = b->z + dt * b->vz;
  }
}

static double NBodySystem_energy(const NBodySystem* self) {
  double e = 0.0;

  for (int32_t i = 0; i < self->bodies_size; i += 1) {
    const Body* i_body = &self->bodies[i];
    e += 0.5 * i_body->mass *
         (i_body->vx * i_body->vx + i_body->vy * i_body->vy +
          i_body->vz * i_body->vz);

    for (int32_t j = i + 1; j < self->bodies_size; j += 1) {
      const Body* j_body = &self->bodies[j];
      const double dx = i_body->x - j_body->x;
      const double dy = i_body->y - j_body->y;
      const double dz = i_body->z - j_body->z;

      const double distance = sqrt(dx * dx + dy * dy + dz * dz);
      e -= (i_body->mass * j_body->mass) / distance;
    }
  }
  return e;
}

static bool verify(double result, int32_t inner_iterations) {
  if (inner_iterations == 250000) {
    return result == -0.1690859889909308;
  }
  if (inner_iterations == 1) {
    return result == -0.16907495402506745;
  }

  printf("No verification result for %d found\n", inner_iterations);
  printf("Result is: %.17g\n", result);
  return false;
}

static bool NBody_inner_benchmark_loop(Benchmark* self,
                                       int32_t inner_iterations) {
  (void)self;
  NBodySystem system;
  NBodySystem_init(&system);
  for (int32_t i = 0; i < inner_iterations; i += 1) {
    NBodySystem_advance(&system, 0.01);
  }

  return verify(NBodySystem_energy(&system), inner_iterations);
}

static Result NBody_benchmark(Benchmark* self) {
  (void)self;
  error("Should never be reached");
}

static bool NBody_verify_result(Benchmark* self, Result result) {
  (void)self;
  (void)result;
  error("Should never be reached");
}

static const BenchmarkVtbl NBody_vtbl = {Benchmark_destroy, NBody_benchmark,
                                         NBody_verify_result,
                                         NBody_inner_benchmark_loop};

Benchmark* NBody_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &NBody_vtbl);
}
