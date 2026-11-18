/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Greg Buchholz
 *
 * Tuned for this suite, after Jeremy Zerfas's mandelbrot.gcc-9 (eight pixels
 * per byte computed together) and the Rust mandelbrot's eight-lane form:
 * two output bytes (sixteen pixels) per pass as two eight-lane clang
 * vectors, so eight independent two-lane NEON chains keep the floating-point
 * pipes busy; the initial real and imaginary parts precomputed per column
 * and row; the escape test made every fifth iteration instead of every one
 * (a pixel that has escaped only grows, or overflows to inf/NaN, which fail
 * `<= 4` too, so the extra iterations cannot bring it back and the image is
 * the same); the image written with one fwrite. Same work: up to 50
 * iterations per pixel, bits packed eight to a byte.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef double v8d __attribute__((vector_size(64)));
typedef int64_t v8l __attribute__((vector_size(64)));

static inline uint8_t bits(v8l inside)
{
   const v8l w = {128, 64, 32, 16, 8, 4, 2, 1};
   v8l m = inside & w;   /* lanes are all-ones where inside */
   int64_t s = 0;
   for (int i = 0; i < 8; i++) s += m[i];
   return (uint8_t)s;
}

/* Two bytes of one row: pixels cra (first byte) and crb (second byte). */
static inline void octets(v8d cra, v8d crb, double ci, uint8_t *out)
{
   const v8d civ = {ci, ci, ci, ci, ci, ci, ci, ci};
   const v8d four = {4, 4, 4, 4, 4, 4, 4, 4};
   v8d zra = {0}, zia = {0}, tra = {0}, tia = {0};
   v8d zrb = {0}, zib = {0}, trb = {0}, tib = {0};
   for (int block = 0; block < 10; block++) {
      v8l in = (tra + tia <= four) | (trb + tib <= four);
      int64_t any = 0;
      for (int i = 0; i < 8; i++) any |= in[i];
      if (!any) break;
      for (int k = 0; k < 5; k++) {
         zia = 2.0 * zra * zia + civ; zib = 2.0 * zrb * zib + civ;
         zra = tra - tia + cra;       zrb = trb - tib + crb;
         tra = zra * zra;             trb = zrb * zrb;
         tia = zia * zia;             tib = zib * zib;
      }
   }
   out[0] = bits(tra + tia <= four);
   out[1] = bits(trb + tib <= four);
}

int main(int argc, char **argv)
{
   const int n = atoi(argv[1]);
   const int bytes = (n + 7) / 8;
   /* columns padded to a whole number of byte pairs */
   const int cols = (bytes + 1) / 2 * 16;
   double *cr = malloc(cols * sizeof *cr);
   uint8_t *image = malloc((size_t)bytes * n + 1);
   for (int x = 0; x < cols; x++) cr[x] = 2.0 * x / n - 1.5;

   for (int y = 0; y < n; y++) {
      const double ci = 2.0 * y / n - 1.0;
      uint8_t *row = image + (size_t)y * bytes;
      uint8_t pair[2];
      for (int b = 0; b < bytes; b += 2) {
         v8d a, c;
         __builtin_memcpy(&a, cr + 8 * b, 64);
         __builtin_memcpy(&c, cr + 8 * b + 8, 64);
         octets(a, c, ci, pair);
         row[b] = pair[0];
         if (b + 1 < bytes) row[b + 1] = pair[1];
      }
      if (n % 8) row[bytes - 1] &= (uint8_t)(0xFF << (8 - n % 8));
   }

   printf("P4\n%d %d\n", n, n);
   fwrite(image, 1, (size_t)bytes * n, stdout);
   return 0;
}
