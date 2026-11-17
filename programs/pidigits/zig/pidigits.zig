// The Computer Language Benchmarks Game: pidigits. A port of the C program (Mr Ledrug's), written
// for this suite: Gibbons' spigot over GMP, through extern declarations of gmp.h's __gmpz_* symbols
// (build.zsh passes -lgmp), output through stdio as the C program does.

const Mpz = extern struct { alloc: c_int, size: c_int, d: ?*anyopaque };

extern "gmp" fn __gmpz_init(x: *Mpz) void;
extern "gmp" fn __gmpz_init_set_ui(x: *Mpz, v: c_ulong) void;
extern "gmp" fn __gmpz_add(r: *Mpz, a: *const Mpz, b: *const Mpz) void;
extern "gmp" fn __gmpz_mul_ui(r: *Mpz, a: *const Mpz, b: c_ulong) void;
extern "gmp" fn __gmpz_addmul_ui(r: *Mpz, a: *const Mpz, b: c_ulong) void;
extern "gmp" fn __gmpz_submul_ui(r: *Mpz, a: *const Mpz, b: c_ulong) void;
extern "gmp" fn __gmpz_tdiv_q(q: *Mpz, n: *const Mpz, d: *const Mpz) void;
extern "gmp" fn __gmpz_get_ui(x: *const Mpz) c_ulong;
extern "gmp" fn __gmpz_cmp(a: *const Mpz, b: *const Mpz) c_int;

extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn putchar(c: c_int) c_int;

var tmp1: Mpz = undefined;
var tmp2: Mpz = undefined;
var acc: Mpz = undefined;
var den: Mpz = undefined;
var num: Mpz = undefined;

fn extractDigit(nth: c_uint) c_uint {
    // joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
    __gmpz_mul_ui(&tmp1, &num, nth);
    __gmpz_add(&tmp2, &tmp1, &acc);
    __gmpz_tdiv_q(&tmp1, &tmp2, &den);
    return @intCast(__gmpz_get_ui(&tmp1));
}

fn eliminateDigit(d: c_uint) void {
    __gmpz_submul_ui(&acc, &den, d);
    __gmpz_mul_ui(&acc, &acc, 10);
    __gmpz_mul_ui(&num, &num, 10);
}

fn nextTerm(k: c_uint) void {
    const k2 = k * 2 + 1;
    __gmpz_addmul_ui(&acc, &num, 2);
    __gmpz_mul_ui(&acc, &acc, k2);
    __gmpz_mul_ui(&den, &den, k2);
    __gmpz_mul_ui(&num, &num, k);
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const n: c_uint = @intCast(atoi(argv[1]));

    __gmpz_init(&tmp1);
    __gmpz_init(&tmp2);
    __gmpz_init_set_ui(&acc, 0);
    __gmpz_init_set_ui(&den, 1);
    __gmpz_init_set_ui(&num, 1);

    var i: c_uint = 0;
    var k: c_uint = 0;
    while (i < n) {
        k += 1;
        nextTerm(k);
        if (__gmpz_cmp(&num, &acc) > 0) continue;

        const d = extractDigit(3);
        if (d != extractDigit(4)) continue;

        _ = putchar(@intCast('0' + d));
        i += 1;
        if (i % 10 == 0) _ = printf("\t:%u\n", i);
        eliminateDigit(d);
    }

    if (n % 10 != 0) _ = printf("%*s\t:%u\n", @as(c_int, @intCast(10 - n % 10)), "", n);
    return 0;
}
