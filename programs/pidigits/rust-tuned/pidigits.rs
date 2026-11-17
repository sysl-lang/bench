// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// Contributed by Matt Brubeck
// Contributed by TeXitoi
// Inspired by Mr Ledrug's C version and thestinger's rust-gmp
// modified by Takumi Kato
//
// Tuned for this suite: one division per candidate digit. q = (3num + acc) / den
// with remainder r by mpz_tdiv_qr, and the 4num digit is the same one exactly
// when r + num < den, so the second division becomes an addition and a
// comparison. MaybeUninit in place of the deprecated mem::uninitialized.

#![allow(non_camel_case_types)]

use std::os::raw::{c_int, c_ulong, c_void};
use std::mem::MaybeUninit;
use std::cmp::Ordering;
use std::io::{stdout, BufWriter, Write};

fn main() {
    let stdout = stdout();
    let mut stdout = BufWriter::new(stdout.lock());
    let n = std::env::args_os()
        .nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(27);
    for (i, d) in Context::new().enumerate().take(n) {
        let _ = write!(stdout, "{}", d);
        if i % 10 == 9 {
            let _ = writeln!(stdout, "\t:{}", i + 1);
        }
    }
    if n % 10 != 0 {
        for _ in n % 10..10 {
            let _ = stdout.write(b" ");
        }
        let _ = writeln!(stdout, "\t:{}", n);
    }
}

pub struct Context {
    k: c_ulong,
    q: Mpz,
    r: Mpz,
    tmp: Mpz,
    acc: Mpz,
    den: Mpz,
    num: Mpz,
}
impl Context {
    pub fn new() -> Context {
        Context {
            k: 0,
            q: Mpz::from_ui(0),
            r: Mpz::from_ui(0),
            tmp: Mpz::from_ui(0),
            acc: Mpz::from_ui(0),
            den: Mpz::from_ui(1),
            num: Mpz::from_ui(1),
        }
    }
    // The digit (3num + acc) / den when (4num + acc) / den agrees with it.
    fn extract_digit(&mut self) -> Option<c_ulong> {
        self.tmp.mul_ui(&self.num, 3);
        self.tmp.add_from(&self.acc);
        self.q.tdiv_qr(&mut self.r, &self.tmp, &self.den);
        self.r.add_from(&self.num);
        if self.r >= self.den {
            None
        } else {
            Some(self.q.as_ui())
        }
    }
    fn eliminate_digit(&mut self, d: c_ulong) {
        self.acc.submul_ui(&self.den, d);
        self.acc.mul_from_ui(10);
        self.num.mul_from_ui(10);
    }
    fn next_term(&mut self) {
        self.k += 1;
        let k2 = self.k * 2 + 1;
        self.acc.addmul_ui(&self.num, 2);
        self.acc.mul_from_ui(k2);
        self.den.mul_from_ui(k2);
        self.num.mul_from_ui(self.k);
    }
}
impl Iterator for Context {
    type Item = c_ulong;
    fn next(&mut self) -> Option<c_ulong> {
        loop {
            self.next_term();
            if self.num > self.acc {
                continue;
            }
            if let Some(d) = self.extract_digit() {
                self.eliminate_digit(d);
                return Some(d);
            }
        }
    }
}

// safe bindings to needed GMP functions
pub struct Mpz {
    mpz: mpz_struct,
}
impl Drop for Mpz {
    fn drop(&mut self) {
        unsafe { __gmpz_clear(&mut self.mpz) }
    }
}
impl Mpz {
    pub fn from_ui(i: c_ulong) -> Mpz {
        unsafe {
            let mut mpz = MaybeUninit::uninit();
            __gmpz_init_set_ui(mpz.as_mut_ptr(), i);
            Mpz { mpz: mpz.assume_init() }
        }
    }
    // self = a * b
    pub fn mul_ui(&mut self, a: &Mpz, b: c_ulong) {
        unsafe {
            __gmpz_mul_ui(&mut self.mpz, &a.mpz, b);
        }
    }
    // self *= a
    pub fn mul_from_ui(&mut self, a: c_ulong) {
        unsafe {
            __gmpz_mul_ui(&mut self.mpz, &self.mpz, a);
        }
    }
    // self -= a * b
    pub fn submul_ui(&mut self, a: &Mpz, b: c_ulong) {
        unsafe {
            __gmpz_submul_ui(&mut self.mpz, &a.mpz, b);
        }
    }
    // self = a + b
    pub fn add(&mut self, a: &Mpz, b: &Mpz) {
        unsafe {
            __gmpz_add(&mut self.mpz, &a.mpz, &b.mpz);
        }
    }
    // self += a
    pub fn add_from(&mut self, a: &Mpz) {
        unsafe {
            __gmpz_add(&mut self.mpz, &self.mpz, &a.mpz);
        }
    }
    // self = n / d, r = n % d, truncated
    pub fn tdiv_qr(&mut self, r: &mut Mpz, n: &Mpz, d: &Mpz) {
        unsafe {
            __gmpz_tdiv_qr(&mut self.mpz, &mut r.mpz, &n.mpz, &d.mpz);
        }
    }
    // self += a * b
    pub fn addmul_ui(&mut self, a: &Mpz, b: c_ulong) {
        unsafe {
            __gmpz_addmul_ui(&mut self.mpz, &a.mpz, b);
        }
    }
    // self = a / b
    pub fn tdiv_q(&mut self, a: &Mpz, b: &Mpz) {
        unsafe {
            __gmpz_tdiv_q(&mut self.mpz, &a.mpz, &b.mpz);
        }
    }
    pub fn as_ui(&self) -> c_ulong {
        unsafe { __gmpz_get_ui(&self.mpz) }
    }
}
impl Eq for Mpz {}
impl PartialEq for Mpz {
    fn eq(&self, other: &Mpz) -> bool {
        unsafe { __gmpz_cmp(&self.mpz, &other.mpz) == 0 }
    }
}
impl Ord for Mpz {
    fn cmp(&self, other: &Mpz) -> Ordering {
        let cmp = unsafe { __gmpz_cmp(&self.mpz, &other.mpz) };
        if cmp == 0 {
            Ordering::Equal
        } else if cmp < 0 {
            Ordering::Less
        } else {
            Ordering::Greater
        }
    }
}
impl PartialOrd for Mpz {
    fn partial_cmp(&self, other: &Mpz) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

// Raw bindings to needed GMP functions
#[repr(C)]
struct mpz_struct {
    _mp_alloc: c_int,
    _mp_size: c_int,
    _mp_d: *mut c_void,
}

type mpz_ptr = *mut mpz_struct;
type mpz_srcptr = *const mpz_struct;

#[link(name = "gmp")]
extern "C" {
    fn __gmpz_init_set_ui(rop: mpz_ptr, op: c_ulong);
    fn __gmpz_clear(x: mpz_ptr);
    fn __gmpz_get_ui(op: mpz_srcptr) -> c_ulong;
    fn __gmpz_cmp(op1: mpz_srcptr, op2: mpz_srcptr) -> c_int;
    fn __gmpz_add(rop: mpz_ptr, op1: mpz_srcptr, op2: mpz_srcptr);
    fn __gmpz_mul_ui(rop: mpz_ptr, op1: mpz_srcptr, op2: c_ulong);
    fn __gmpz_submul_ui(rop: mpz_ptr, op1: mpz_srcptr, op2: c_ulong);
    fn __gmpz_addmul_ui(rop: mpz_ptr, op1: mpz_srcptr, op2: c_ulong);
    fn __gmpz_tdiv_q(q: mpz_ptr, n: mpz_srcptr, d: mpz_srcptr);
    fn __gmpz_tdiv_qr(q: mpz_ptr, r: mpz_ptr, n: mpz_srcptr, d: mpz_srcptr);
}
