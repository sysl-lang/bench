// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Mr Ledrug) to C3: GMP through
// extern declarations of gmp.h's __gmpz_* symbols (build.zsh passes -l gmp),
// output through libc stdio as the C program does.
module pidigits;
import libc;

struct Mpz
{
	CInt alloc;
	CInt size;
	void* d;
}

extern fn void mpz_init(Mpz* x) @cname("__gmpz_init");
extern fn void mpz_init_set_ui(Mpz* x, CULong v) @cname("__gmpz_init_set_ui");
extern fn void mpz_add(Mpz* r, Mpz* a, Mpz* b) @cname("__gmpz_add");
extern fn void mpz_mul_ui(Mpz* r, Mpz* a, CULong b) @cname("__gmpz_mul_ui");
extern fn void mpz_addmul_ui(Mpz* r, Mpz* a, CULong b) @cname("__gmpz_addmul_ui");
extern fn void mpz_submul_ui(Mpz* r, Mpz* a, CULong b) @cname("__gmpz_submul_ui");
extern fn void mpz_tdiv_q(Mpz* q, Mpz* n, Mpz* d) @cname("__gmpz_tdiv_q");
extern fn CULong mpz_get_ui(Mpz* x) @cname("__gmpz_get_ui");
extern fn CInt mpz_cmp(Mpz* a, Mpz* b) @cname("__gmpz_cmp");

Mpz tmp1;
Mpz tmp2;
Mpz acc;
Mpz den;
Mpz num;

fn uint extract_digit(uint nth)
{
	// joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
	mpz_mul_ui(&tmp1, &num, nth);
	mpz_add(&tmp2, &tmp1, &acc);
	mpz_tdiv_q(&tmp1, &tmp2, &den);
	return (uint)mpz_get_ui(&tmp1);
}

fn void eliminate_digit(uint d)
{
	mpz_submul_ui(&acc, &den, d);
	mpz_mul_ui(&acc, &acc, 10);
	mpz_mul_ui(&num, &num, 10);
}

fn void next_term(uint k)
{
	uint k2 = k * 2 + 1;
	mpz_addmul_ui(&acc, &num, 2);
	mpz_mul_ui(&acc, &acc, k2);
	mpz_mul_ui(&den, &den, k2);
	mpz_mul_ui(&num, &num, k);
}

fn int main(String[] args)
{
	uint n = (uint)args[1].to_int()!!;

	mpz_init(&tmp1);
	mpz_init(&tmp2);
	mpz_init_set_ui(&acc, 0);
	mpz_init_set_ui(&den, 1);
	mpz_init_set_ui(&num, 1);

	uint i = 0;
	uint k = 0;
	while (i < n)
	{
		next_term(++k);
		if (mpz_cmp(&num, &acc) > 0) continue;

		uint d = extract_digit(3);
		if (d != extract_digit(4)) continue;

		libc::putchar((CInt)('0' + d));
		if (++i % 10 == 0) libc::printf("\t:%u\n", i);
		eliminate_digit(d);
	}

	if (n % 10 != 0) libc::printf("%*s\t:%u\n", (CInt)(10 - n % 10), "", n);
	return 0;
}
