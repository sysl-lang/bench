/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * Contributed by Mr Ledrug
 *
 * Ported to D for this suite: GMP through extern(C) declarations.
*/

import core.stdc.config : c_ulong;
import core.stdc.stdio : printf, putchar;
import core.stdc.stdlib : atoi;

pragma(lib, "gmp");

// __mpz_struct from gmp.h; gmp.h's public names are macros over the __gmpz_* symbols.
struct mpz_t { int alloc; int size; void* d; }

extern (C) nothrow @nogc {
   void __gmpz_init(mpz_t*);
   void __gmpz_init_set_ui(mpz_t*, c_ulong);
   void __gmpz_add(mpz_t*, const(mpz_t)*, const(mpz_t)*);
   void __gmpz_mul_ui(mpz_t*, const(mpz_t)*, c_ulong);
   void __gmpz_addmul_ui(mpz_t*, const(mpz_t)*, c_ulong);
   void __gmpz_submul_ui(mpz_t*, const(mpz_t)*, c_ulong);
   void __gmpz_tdiv_q(mpz_t*, const(mpz_t)*, const(mpz_t)*);
   c_ulong __gmpz_get_ui(const(mpz_t)*);
   int __gmpz_cmp(const(mpz_t)*, const(mpz_t)*);
}

__gshared mpz_t tmp1, tmp2, acc, den, num;

uint extract_digit(uint nth) {
   // joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
   __gmpz_mul_ui(&tmp1, &num, nth);
   __gmpz_add(&tmp2, &tmp1, &acc);
   __gmpz_tdiv_q(&tmp1, &tmp2, &den);

   return cast(uint) __gmpz_get_ui(&tmp1);
}

void eliminate_digit(uint d) {
   __gmpz_submul_ui(&acc, &den, d);
   __gmpz_mul_ui(&acc, &acc, 10);
   __gmpz_mul_ui(&num, &num, 10);
}

void next_term(uint k) {
   uint k2 = k * 2U + 1U;

   __gmpz_addmul_ui(&acc, &num, 2U);
   __gmpz_mul_ui(&acc, &acc, k2);
   __gmpz_mul_ui(&den, &den, k2);
   __gmpz_mul_ui(&num, &num, k);
}

extern (C) int main(int argc, char** argv) {
   uint d, k, i;
   int n = atoi(argv[1]);

   __gmpz_init(&tmp1);
   __gmpz_init(&tmp2);

   __gmpz_init_set_ui(&acc, 0);
   __gmpz_init_set_ui(&den, 1);
   __gmpz_init_set_ui(&num, 1);

   for (i = k = 0; i < n;) {
      next_term(++k);
      if (__gmpz_cmp(&num, &acc) > 0)
         continue;

      d = extract_digit(3);
      if (d != extract_digit(4))
         continue;

      putchar('0' + d);
      if (++i % 10 == 0)
         printf("\t:%u\n", i);
      eliminate_digit(d);
   }

   if (n % 10 != 0)
      printf("%*s\t:%d\n", 10 - n % 10, "".ptr, n);

   return 0;
}
