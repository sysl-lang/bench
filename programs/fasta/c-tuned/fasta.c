/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * by Drake Diedrich
 *
 * Tuned for this suite. The generator's state sequence and every symbol
 * choice are the same as the plain program's; three things are faster:
 *
 * - The generator step `seed = (seed * IA + IC) % IM` is the program's
 *   critical path. The remainder is taken with Lemire's fastmod (M =
 *   ceil(2^64 / IM); x % IM = high64(lo64(M * x) * IM), exact for every
 *   32-bit x), and the multiply-add is folded into it: lo64(M * (seed * IA +
 *   IC)) = lo64(seed * (M * IA) + M * IC). One multiply-add and one
 *   high multiply per step, where the compiler's remainder costs a
 *   multiply-add, a high multiply, a shift and a multiply-subtract.
 * - The cumulative-probability scan counts the probabilities below the
 *   variate over the whole table (the plain program's branch-free
 *   linear_lookup), with each probability turned once into the least
 *   integer state that exceeds it, so a step compares the state against
 *   four thresholds per NEON instruction and needs no divide.
 * - Lines are built in one large buffer written with write(2), and the
 *   repeated sequence is written from a buffer of whole lines.
 */

#include <arm_neon.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define IM 139968
#define IA   3877
#define IC  29573
#define SEED   42

static uint32_t seed = SEED;
#define FASTMOD_M (UINT64_MAX / IM + 1)
static const uint64_t MA = FASTMOD_M * IA, MC = FASTMOD_M * IC;

static inline uint32_t next_seed(void)
{
  uint64_t low = (uint64_t)seed * MA + MC;           /* = lo64(M * (seed*IA + IC)) */
  seed = (uint32_t)(((unsigned __int128)low * IM) >> 64);
  return seed;
}

static const char *alu =
  "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
  "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
  "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
  "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
  "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
  "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
  "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

static const char *iub = "acgtBDHKMNRSVWY";
static const double iub_p[] = {
  0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02 };

static const char *homosapiens = "acgt";
static const double homosapiens_p[] = {
  0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008 };

#define LINELEN 60
#define BUFLINES 1024

static char out[BUFLINES * (LINELEN + 1)];
static size_t used;

static void flush(void)
{
  const char *p = out;
  while (used) {
    ssize_t w = write(1, p, used);
    if (w <= 0) exit(1);
    p += w; used -= w;
  }
}

static void put(const char *s, size_t n)
{
  while (n) {
    size_t k = sizeof out - used < n ? sizeof out - used : n;
    memcpy(out + used, s, k);
    used += k; s += k; n -= k;
    if (used == sizeof out) flush();
  }
}

static void repeat_fasta(const char *seq, const int n)
{
  const int len = strlen(seq);
  /* len whole lines: after len lines the text starts over at offset 0 */
  char *lines = malloc((size_t)len * (LINELEN + 1));
  for (int i = 0; i < len; i++) {
    for (int k = 0; k < LINELEN; k++) lines[i * (LINELEN + 1) + k] = seq[(i * LINELEN + k) % len];
    lines[i * (LINELEN + 1) + LINELEN] = '\n';
  }
  int whole = n / LINELEN, line = 0;
  for (int i = 0; i < whole; i++) {
    put(lines + line * (LINELEN + 1), LINELEN + 1);
    if (++line == len) line = 0;
  }
  int rest = n % LINELEN;
  if (rest) {
    put(lines + line * (LINELEN + 1), rest);
    put("\n", 1);
  }
  free(lines);
}

/* Number of cumulative probabilities below the variate, scanning all of
 * them (the index of the symbol, as the plain program's branch-free
 * linear_lookup), four thresholds per compare. */
static inline int lookup(const uint32x4_t *t, int quads, uint32_t s)
{
  uint32x4_t sv = vdupq_n_u32(s);
  uint32x4_t count = vdupq_n_u32(0);
  for (int j = 0; j < quads; j++) count = vsubq_u32(count, vcgeq_u32(sv, t[j]));
  return (int)vaddvq_u32(count);
}

static void random_fasta(const char *symb, const double *probability, const int n)
{
  const int len = strlen(symb);
  /* The plain program tests `seed / IM > p[j]` in double for the first len-1
   * cumulative probabilities p[j]. That test is true exactly when seed is at
   * least t[j], the least integer for which it holds, so the scan compares
   * the integer state against t[j] (the scaling the plain Rust program also
   * uses). Unused slots hold UINT32_MAX, which no seed reaches. */
  uint32_t t[16];
  for (int i = 0; i < 16; i++) t[i] = UINT32_MAX;
  double p = 0;
  for (int j = 0; j < len - 1; j++) {
    p = j ? probability[j] + p : probability[0];
    uint32_t s = (uint32_t)(p * IM);
    while (s > 0 && 1.0 * (s - 1) / IM > p) s--;
    while (!(1.0 * s / IM > p)) s++;
    t[j] = s;
  }
  const int quads = (len - 1 + 3) / 4;
  uint32x4_t tv[4];
  for (int j = 0; j < 4; j++) tv[j] = vld1q_u32(t + 4 * j);

  char line[LINELEN + 1];
  line[LINELEN] = '\n';
  int i;
  for (i = 0; i + LINELEN <= n; i += LINELEN) {
    for (int k = 0; k < LINELEN; k++) line[k] = symb[lookup(tv, quads, next_seed())];
    put(line, LINELEN + 1);
  }
  if (i < n) {
    int k = 0;
    for (; i < n; i++, k++) line[k] = symb[lookup(tv, quads, next_seed())];
    line[k] = '\n';
    put(line, k + 1);
  }
}

int main(int argc, char **argv)
{
  int n = 1000;
  if (argc > 1) n = atoi(argv[1]);

  static const char h1[] = ">ONE Homo sapiens alu\n";
  static const char h2[] = ">TWO IUB ambiguity codes\n";
  static const char h3[] = ">THREE Homo sapiens frequency\n";
  put(h1, sizeof h1 - 1);
  repeat_fasta(alu, n * 2);
  put(h2, sizeof h2 - 1);
  random_fasta(iub, iub_p, n * 3);
  put(h3, sizeof h3 - 1);
  random_fasta(homosapiens, homosapiens_p, n * 5);
  flush();
  return 0;
}
