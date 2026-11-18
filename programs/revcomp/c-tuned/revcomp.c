/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Bob W
 *
 * Tuned for this suite: standard input is read whole with read(2) and the
 * output written with write(2). Each record's sequence lines are joined with
 * memchr/memcpy, then reverse-complemented sixteen bytes at a time from both
 * ends with NEON: the complement is the same table as before (the C
 * program's table repeats one 32-entry row for upper and lower case, so it
 * is looked up by the low five bits with one two-register TBL), and the
 * reversal is a REV64 plus a swap of halves. The result is re-wrapped at 60
 * with memcpy. Same work: each record read whole, complemented through a
 * table, reversed and re-wrapped at 60.
 */

#include <arm_neon.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define V32 "\0TVGH\0\0CD\0\0M\0KN\0\0\0YSA\0BW\0R\0\0\0\0\0\0"

static uint8_t comp[32];

static inline uint8x16_t revcomp16(uint8x16_t v, uint8x16x2_t tab)
{
  uint8x16_t c = vqtbl2q_u8(tab, vandq_u8(v, vdupq_n_u8(31)));
  c = vrev64q_u8(c);
  return vextq_u8(c, c, 8);
}

/* Reverse-complements s[0..n) in place. */
static void reverse_complement(uint8_t *s, size_t n)
{
  const uint8x16x2_t tab = { { vld1q_u8(comp), vld1q_u8(comp + 16) } };
  uint8_t *lo = s, *hi = s + n;
  while (hi - lo >= 32) {
    uint8x16_t a = vld1q_u8(lo), b = vld1q_u8(hi - 16);
    vst1q_u8(lo, revcomp16(b, tab));
    vst1q_u8(hi - 16, revcomp16(a, tab));
    lo += 16; hi -= 16;
  }
  while (hi - lo >= 2) {
    uint8_t a = *lo, b = *--hi;
    *lo++ = comp[b & 31];
    *hi = comp[a & 31];
  }
  if (lo < hi) *lo = comp[*lo & 31];
}

static void write_all(const uint8_t *p, size_t n)
{
  while (n) {
    ssize_t w = write(1, p, n);
    if (w <= 0) exit(1);
    p += w; n -= w;
  }
}

int main(void)
{
  memcpy(comp, V32, 32);

  size_t cap = 1 << 24, len = 0;
  uint8_t *in = malloc(cap);
  for (;;) {
    if (len == cap) in = realloc(in, cap *= 2);
    ssize_t r = read(0, in + len, cap - len);
    if (r <= 0) break;
    len += r;
  }

  uint8_t *out = malloc(len + len / 60 + 64);
  uint8_t *seq = malloc(len + 1);
  size_t o = 0, i = 0;
  while (i < len) {
    /* header line, copied as it is */
    uint8_t *nl = memchr(in + i, '\n', len - i);
    size_t hend = nl ? (size_t)(nl - in) + 1 : len;
    memcpy(out + o, in + i, hend - i);
    o += hend - i;
    i = hend;

    /* sequence lines up to the next '>' joined into seq */
    uint8_t *gt = memchr(in + i, '>', len - i);
    size_t send = gt ? (size_t)(gt - in) : len;
    size_t n = 0;
    while (i < send) {
      uint8_t *e = memchr(in + i, '\n', send - i);
      size_t lend = e ? (size_t)(e - in) : send;
      memcpy(seq + n, in + i, lend - i);
      n += lend - i;
      i = e ? lend + 1 : send;
    }

    reverse_complement(seq, n);

    size_t k = 0;
    for (; k + 60 <= n; k += 60) {
      memcpy(out + o, seq + k, 60);
      out[o + 60] = '\n';
      o += 61;
    }
    if (k < n) {
      memcpy(out + o, seq + k, n - k);
      o += n - k;
      out[o++] = '\n';
    }
  }
  write_all(out, o);
  return 0;
}
