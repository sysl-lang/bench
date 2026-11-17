/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * contributed by Ledrug Katz
 *
 * Tuned for this suite: the permutation is one 16-byte NEON register. Flipping
 * the first k+1 elements is one table lookup (TBL) through a precomputed
 * reversal mask chosen at run time by k, and the rotation that steps to the
 * next permutation is one TBL through a precomputed rotation mask. The
 * permutations are visited in the same order as before (the count array of
 * the Tompkin-Paige scheme), and each is flipped until 0 (1 in the puzzle's
 * numbering) leads.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <arm_neon.h>

static uint8_t rev_mask[16][16], rot_mask[16][16];

int main(int argc, char **v)
{
   if (argc < 2) {
      fprintf(stderr, "usage: %s number\n", v[0]);
      exit(1);
   }
   int n = atoi(v[1]);
   if (n < 3 || n > 15) {
      fprintf(stderr, "range: must be 3 <= n <= 15\n");
      exit(1);
   }

   for (int k = 0; k < 16; k++)
      for (int i = 0; i < 16; i++) {
         rev_mask[k][i] = i <= k ? k - i : i;          /* reverse lanes 0..k */
         rot_mask[k][i] = i < k ? i + 1 : i == k ? 0 : i; /* rotate lanes 0..k left by one */
      }

   uint8_t init[16];
   for (int i = 0; i < 16; i++) init[i] = i;
   uint8x16_t perm = vld1q_u8(init);
   int count[16] = {0};
   int maxflips = 0, checksum = 0, odd = 0;

   for (;;) {
      unsigned first = vgetq_lane_u8(perm, 0);
      if (first) {
         uint8x16_t t = perm;
         int flips = 0;
         do {
            t = vqtbl1q_u8(t, vld1q_u8(rev_mask[first]));
            flips++;
            first = vgetq_lane_u8(t, 0);
         } while (first);
         if (flips > maxflips) maxflips = flips;
         checksum += odd ? -flips : flips;
      }
      /* next permutation: rotate the first i+1 until a counter can advance */
      int i = 1;
      for (;;) {
         if (i >= n) goto done;
         perm = vqtbl1q_u8(perm, vld1q_u8(rot_mask[i]));
         if (count[i] < i) { count[i]++; break; }
         count[i++] = 0;
      }
      odd = !odd;
   }
done:
   printf("%d\nPfannkuchen(%d) = %d\n", checksum, n, maxflips);
   return 0;
}
