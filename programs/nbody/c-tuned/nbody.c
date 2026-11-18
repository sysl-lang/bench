/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Christoph Bauer
 * modified by Danny Angelo Carminati Grein
 *
 * Tuned for this suite: the bodies are kept as fixed arrays, one per field
 * (structure of arrays), and each step first computes the ten pairwise
 * differences into fixed arrays, then their distances and magnitudes as
 * two-lane vectors (five sqrt and five divide instructions instead of ten
 * each), then the velocity updates. Same work: the pairwise advance of five
 * bodies with an exact sqrt and divide per pair.
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define pi 3.141592653589793
#define solar_mass (4 * pi * pi)
#define days_per_year 365.24

#define NBODIES 5
#define NPAIRS (NBODIES * (NBODIES - 1) / 2)

typedef double v2d __attribute__((vector_size(16)));

static double x[NBODIES], y[NBODIES], z[NBODIES];
static double vx[NBODIES], vy[NBODIES], vz[NBODIES];
static double mass[NBODIES];

static void advance(int steps, double dt)
{
  double dx[NPAIRS + 1], dy[NPAIRS + 1], dz[NPAIRS + 1];
  double mag[NPAIRS + 1];
  const v2d dtv = {dt, dt};

  for (int s = 0; s < steps; s++) {
    int k = 0;
    for (int i = 0; i < NBODIES; i++)
      for (int j = i + 1; j < NBODIES; j++, k++) {
        dx[k] = x[i] - x[j];
        dy[k] = y[i] - y[j];
        dz[k] = z[i] - z[j];
      }
    for (k = 0; k < NPAIRS; k += 2) {
      v2d ax, ay, az;
      __builtin_memcpy(&ax, dx + k, 16);
      __builtin_memcpy(&ay, dy + k, 16);
      __builtin_memcpy(&az, dz + k, 16);
      v2d d2 = ax * ax + ay * ay + az * az;
      v2d d = __builtin_elementwise_sqrt(d2);
      v2d m = dtv / (d2 * d);
      __builtin_memcpy(mag + k, &m, 16);
    }
    k = 0;
    for (int i = 0; i < NBODIES; i++)
      for (int j = i + 1; j < NBODIES; j++, k++) {
        double mj = mass[j] * mag[k], mi = mass[i] * mag[k];
        vx[i] -= dx[k] * mj; vy[i] -= dy[k] * mj; vz[i] -= dz[k] * mj;
        vx[j] += dx[k] * mi; vy[j] += dy[k] * mi; vz[j] += dz[k] * mi;
      }
    for (int i = 0; i < NBODIES; i++) {
      x[i] += dt * vx[i];
      y[i] += dt * vy[i];
      z[i] += dt * vz[i];
    }
  }
}

static double energy(void)
{
  double e = 0.0;
  for (int i = 0; i < NBODIES; i++) {
    e += 0.5 * mass[i] * (vx[i] * vx[i] + vy[i] * vy[i] + vz[i] * vz[i]);
    for (int j = i + 1; j < NBODIES; j++) {
      double ddx = x[i] - x[j], ddy = y[i] - y[j], ddz = z[i] - z[j];
      e -= (mass[i] * mass[j]) / sqrt(ddx * ddx + ddy * ddy + ddz * ddz);
    }
  }
  return e;
}

static void offset_momentum(void)
{
  double px = 0.0, py = 0.0, pz = 0.0;
  for (int i = 0; i < NBODIES; i++) {
    px += vx[i] * mass[i];
    py += vy[i] * mass[i];
    pz += vz[i] * mass[i];
  }
  vx[0] = - px / solar_mass;
  vy[0] = - py / solar_mass;
  vz[0] = - pz / solar_mass;
}

static const double init[NBODIES][7] = {
  { 0, 0, 0, 0, 0, 0, solar_mass },                                  /* sun */
  { 4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
    1.66007664274403694e-03 * days_per_year, 7.69901118419740425e-03 * days_per_year,
    -6.90460016972063023e-05 * days_per_year, 9.54791938424326609e-04 * solar_mass },  /* jupiter */
  { 8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
    -2.76742510726862411e-03 * days_per_year, 4.99852801234917238e-03 * days_per_year,
    2.30417297573763929e-05 * days_per_year, 2.85885980666130812e-04 * solar_mass },   /* saturn */
  { 1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
    2.96460137564761618e-03 * days_per_year, 2.37847173959480950e-03 * days_per_year,
    -2.96589568540237556e-05 * days_per_year, 4.36624404335156298e-05 * solar_mass },  /* uranus */
  { 1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
    2.68067772490389322e-03 * days_per_year, 1.62824170038242295e-03 * days_per_year,
    -9.51592254519715870e-05 * days_per_year, 5.15138902046611451e-05 * solar_mass }   /* neptune */
};

int main(int argc, char ** argv)
{
  int n = atoi(argv[1]);
  for (int i = 0; i < NBODIES; i++) {
    x[i] = init[i][0]; y[i] = init[i][1]; z[i] = init[i][2];
    vx[i] = init[i][3]; vy[i] = init[i][4]; vz[i] = init[i][5];
    mass[i] = init[i][6];
  }
  offset_momentum();
  printf("%.9f\n", energy());
  advance(n, 0.01);
  printf("%.9f\n", energy());
  return 0;
}
