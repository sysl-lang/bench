// The Computer Language Benchmarks Game: pidigits. Original, written for this benchmark. It mirrors
// the Game's fastest C program (pidigits.gcc-2, Michael Ganss, Oleksii Prudkyi and Craig Russell, from
// Mike Pall and Wim Couwenberg's pidigits.lua-5), which is single-threaded: the spigot kept as two
// numerators n1, n2 and a denominator d; a digit is emitted when n1/d and n2/d agree, otherwise the
// next term is produced. GMP through extern declarations of gmp.h's __gmpz_* symbols (build.zsh
// passes -l gmp); output through libc stdio, as gcc-2's.
module pidigits;
import libc;

struct Mpz
{
	CInt alloc;
	CInt size;
	void* d;
}

extern fn void mpz_init(Mpz* x) @cname("__gmpz_init");
extern fn void mpz_init_set_si(Mpz* x, CLong v) @cname("__gmpz_init_set_si");
extern fn void mpz_add(Mpz* r, Mpz* a, Mpz* b) @cname("__gmpz_add");
extern fn void mpz_mul(Mpz* r, Mpz* a, Mpz* b) @cname("__gmpz_mul");
extern fn void mpz_mul_si(Mpz* r, Mpz* a, CLong b) @cname("__gmpz_mul_si");
extern fn void mpz_tdiv_q(Mpz* q, Mpz* n, Mpz* d) @cname("__gmpz_tdiv_q");
extern fn CLong mpz_get_si(Mpz* x) @cname("__gmpz_get_si");
extern fn CInt mpz_cmp(Mpz* a, Mpz* b) @cname("__gmpz_cmp");

Mpz n1;
Mpz n2;
Mpz d;
Mpz u;
Mpz v;
Mpz w;

fn int main(String[] args)
{
	int n = args[1].to_int()!!;
	mpz_init(&u);
	mpz_init(&v);
	mpz_init_set_si(&w, 0);
	mpz_init_set_si(&n1, 4);
	mpz_init_set_si(&n2, 3);
	mpz_init_set_si(&d, 1);

	CLong k = 1;
	int i = 0;
	while (true)
	{
		mpz_tdiv_q(&u, &n1, &d);
		mpz_tdiv_q(&v, &n2, &d);
		if (mpz_cmp(&u, &v) == 0)
		{
			libc::putchar((CInt)('0' + mpz_get_si(&u)));
			i++;
			if (i % 10 == 0) libc::printf("\t:%d\n", i);
			if (i == n) break;
			// extract
			mpz_mul_si(&u, &u, -10);
			mpz_mul(&u, &d, &u);
			mpz_mul_si(&n1, &n1, 10);
			mpz_add(&n1, &n1, &u);
			mpz_mul_si(&n2, &n2, 10);
			mpz_add(&n2, &n2, &u);
		}
		else
		{
			// produce
			CLong k2 = k * 2;
			mpz_mul_si(&u, &n1, k2 - 1);
			mpz_add(&v, &n2, &n2);
			mpz_mul_si(&w, &n1, k - 1);
			mpz_add(&n1, &u, &v);
			mpz_mul_si(&u, &n2, k + 2);
			mpz_add(&n2, &w, &u);
			mpz_mul_si(&d, &d, k2 + 1);
			k++;
		}
	}
	if (i % 10 != 0) libc::printf("%*s\t:%d\n", (CInt)(10 - n % 10), "", n);
	return 0;
}
