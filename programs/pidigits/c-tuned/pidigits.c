/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * Contributed by Mr Ledrug
 *
 * Tuned for this suite: one division per candidate digit. q = (3num + acc) / den
 * with remainder r by mpz_tdiv_qr, and the 4num digit is the same one exactly
 * when r + num < den, so the second division of the plain program becomes an
 * addition and a comparison. The output is gathered and written in one call.
*/

#include <stdio.h>
#include <stdlib.h>
#include <gmp.h>

mpz_t tmp, q, r, acc, den, num;
typedef unsigned int ui;

static void eliminate_digit(ui d) {
   mpz_submul_ui(acc, den, d);
   mpz_mul_ui(acc, acc, 10);
   mpz_mul_ui(num, num, 10);
}

static void next_term(ui k) {
   ui k2 = k * 2U + 1U;

   mpz_addmul_ui(acc, num, 2U);
   mpz_mul_ui(acc, acc, k2);
   mpz_mul_ui(den, den, k2);
   mpz_mul_ui(num, num, k);
}

int main(int argc, char **argv) {
   ui d, k, i;
   int n = atoi(argv[1]);
   char *out = malloc((size_t)n / 10 * 24 + 48);
   size_t len = 0;

   mpz_init(tmp);
   mpz_init(q);
   mpz_init(r);

   mpz_init_set_ui(acc, 0);
   mpz_init_set_ui(den, 1);
   mpz_init_set_ui(num, 1);

   for (i = k = 0; i < n;) {
      next_term(++k);
      if (mpz_cmp(num, acc) > 0)
         continue;

      mpz_mul_ui(tmp, num, 3);
      mpz_add(tmp, tmp, acc);
      mpz_tdiv_qr(q, r, tmp, den);
      mpz_add(r, r, num);
      if (mpz_cmp(r, den) >= 0)
         continue;

      d = (ui)mpz_get_ui(q);
      out[len++] = '0' + d;
      if (++i % 10 == 0)
         len += sprintf(out + len, "\t:%u\n", i);
      eliminate_digit(d);
   }

   if (n % 10 != 0)
      len += sprintf(out + len, "%*s\t:%d\n", 10 - n % 10, "", n);

   fwrite(out, 1, len, stdout);
   return 0;
}
