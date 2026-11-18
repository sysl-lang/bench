/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * Contributed by Sebastien Loisel
 *
 * Tuned for this suite: eight columns per step in four two-lane vectors
 * (clang vector extensions), each denominator computed exactly in double
 * from the column index vector, and four independent sums so the divides
 * overlap. Same work: every A[i][j] computed on the fly and divided into.
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef double v2d __attribute__((vector_size(16)));

/* transpose == 0: Au[i] = sum_j A[i][j] u[j]; otherwise sum_j A[j][i] u[j]. */
static inline __attribute__((always_inline)) void times(int N, const double *restrict u, double *restrict Au, int transpose)
{
  for (int i = 0; i < N; i++) {
    v2d s0 = {0, 0}, s1 = {0, 0}, s2 = {0, 0}, s3 = {0, 0};
    const double di = i;
    /* den(i,j) = (i+j)(i+j+1)/2 + i + 1, or + j + 1 for the transpose */
    v2d j0 = {0, 1};
    const v2d two = {2, 2}, eight = {8, 8}, half = {0.5, 0.5}, one = {1, 1};
    const v2d iv = {di, di};
    int j = 0;
    for (; j + 8 <= N; j += 8) {
      v2d ja = j0, jb = j0 + two, jc = j0 + two + two, jd = j0 + two + two + two;
      v2d sa = iv + ja, sb = iv + jb, sc = iv + jc, sd = iv + jd;
      v2d ea = transpose ? ja : iv, eb = transpose ? jb : iv, ec = transpose ? jc : iv, ed = transpose ? jd : iv;
      v2d da = sa * (sa + one) * half + ea + one;
      v2d db = sb * (sb + one) * half + eb + one;
      v2d dc = sc * (sc + one) * half + ec + one;
      v2d dd = sd * (sd + one) * half + ed + one;
      v2d ua, ub, uc, ud;
      __builtin_memcpy(&ua, u + j, 16);
      __builtin_memcpy(&ub, u + j + 2, 16);
      __builtin_memcpy(&uc, u + j + 4, 16);
      __builtin_memcpy(&ud, u + j + 6, 16);
      s0 += ua / da; s1 += ub / db; s2 += uc / dc; s3 += ud / dd;
      j0 += eight;
    }
    v2d s = (s0 + s1) + (s2 + s3);
    double sum = s[0] + s[1];
    for (; j < N; j++) sum += u[j] / (double)((i+j)*(i+j+1)/2 + (transpose ? j : i) + 1);
    Au[i] = sum;
  }
}

static void eval_AtA_times_u(int N, const double u[], double AtAu[], double tmp[])
{ times(N, u, tmp, 0); times(N, tmp, AtAu, 1); }

int main(int argc, char *argv[])
{
  int i;
  const int N = ((argc == 2) ? atoi(argv[1]) : 100);
  double *u = malloc(N * sizeof *u), *v = malloc(N * sizeof *v), *tmp = malloc(N * sizeof *tmp);
  double vBv, vv;
  for (i = 0; i < N; i++) u[i] = 1;
  for (i = 0; i < 10; i++) {
    eval_AtA_times_u(N, u, v, tmp);
    eval_AtA_times_u(N, v, u, tmp);
  }
  vBv = vv = 0;
  for (i = 0; i < N; i++) { vBv += u[i]*v[i]; vv += v[i]*v[i]; }
  printf("%0.9f\n", sqrt(vBv/vv));
  return 0;
}
