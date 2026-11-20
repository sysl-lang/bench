// The Computer Language Benchmarks Game: pidigits. Original, written for this benchmark. It mirrors
// the Game's fastest C program (pidigits.gcc-2, Michael Ganss, Oleksii Prudkyi and Craig Russell, from
// Mike Pall and Wim Couwenberg's pidigits.lua-5), which is single-threaded: the spigot kept as two
// numerators n1, n2 and a denominator d; a digit is emitted when n1/d and n2/d agree, otherwise the
// next term is produced. GMP is called through extern declarations of gmp.h's __gmpz_* symbols
// (build.zsh passes -lgmp); output through stdio, as gcc-2's.

const Mpz = extern struct { alloc: c_int, size: c_int, d: ?*anyopaque };

extern "gmp" fn __gmpz_init(x: *Mpz) void;
extern "gmp" fn __gmpz_init_set_si(x: *Mpz, v: c_long) void;
extern "gmp" fn __gmpz_add(r: *Mpz, a: *const Mpz, b: *const Mpz) void;
extern "gmp" fn __gmpz_mul(r: *Mpz, a: *const Mpz, b: *const Mpz) void;
extern "gmp" fn __gmpz_mul_si(r: *Mpz, a: *const Mpz, b: c_long) void;
extern "gmp" fn __gmpz_tdiv_q(q: *Mpz, n: *const Mpz, d: *const Mpz) void;
extern "gmp" fn __gmpz_get_si(x: *const Mpz) c_long;
extern "gmp" fn __gmpz_cmp(a: *const Mpz, b: *const Mpz) c_int;

extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn putchar(c: c_int) c_int;

var n1: Mpz = undefined;
var n2: Mpz = undefined;
var d: Mpz = undefined;
var u: Mpz = undefined;
var v: Mpz = undefined;
var w: Mpz = undefined;

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const n: c_int = atoi(argv[1]);
    __gmpz_init(&u);
    __gmpz_init(&v);
    __gmpz_init_set_si(&w, 0);
    __gmpz_init_set_si(&n1, 4);
    __gmpz_init_set_si(&n2, 3);
    __gmpz_init_set_si(&d, 1);

    var k: c_long = 1;
    var i: c_int = 0;
    while (true) {
        __gmpz_tdiv_q(&u, &n1, &d);
        __gmpz_tdiv_q(&v, &n2, &d);
        if (__gmpz_cmp(&u, &v) == 0) {
            _ = putchar(@intCast('0' + __gmpz_get_si(&u)));
            i += 1;
            if (@rem(i, 10) == 0) _ = printf("\t:%d\n", i);
            if (i == n) break;
            // extract
            __gmpz_mul_si(&u, &u, -10);
            __gmpz_mul(&u, &d, &u);
            __gmpz_mul_si(&n1, &n1, 10);
            __gmpz_add(&n1, &n1, &u);
            __gmpz_mul_si(&n2, &n2, 10);
            __gmpz_add(&n2, &n2, &u);
        } else {
            // produce
            const k2 = k * 2;
            __gmpz_mul_si(&u, &n1, k2 - 1);
            __gmpz_add(&v, &n2, &n2);
            __gmpz_mul_si(&w, &n1, k - 1);
            __gmpz_add(&n1, &u, &v);
            __gmpz_mul_si(&u, &n2, k + 2);
            __gmpz_add(&n2, &w, &u);
            __gmpz_mul_si(&d, &d, k2 + 1);
            k += 1;
        }
    }
    if (@rem(i, 10) != 0) _ = printf("%*s\t:%d\n", 10 - @rem(n, 10), "", n);
    return 0;
}
