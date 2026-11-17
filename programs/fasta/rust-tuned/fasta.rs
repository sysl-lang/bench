// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by TeXitoi
// contributed by Matt Brubeck
//
// Tuned for this suite. The generator's state sequence and every symbol
// choice are the same as the plain program's; three things are faster:
//
// - The generator step `seed = (seed * IA + IC) % IM` is the program's
//   critical path. The remainder is taken with Lemire's fastmod (M =
//   ceil(2^64 / IM); x % IM = high64(lo64(M * x) * IM), exact for every
//   32-bit x), and the multiply-add is folded into it: lo64(M * (seed * IA +
//   IC)) = lo64(seed * (M * IA) + M * IC). One multiply-add and one high
//   multiply per step.
// - The cumulative-probability scan counts the thresholds the state has
//   reached over the whole table, four per NEON compare (core::arch::aarch64),
//   branch-free. Each threshold is the least state whose variate `seed / IM`
//   exceeds the cumulative probability, computed in f64 exactly as the C
//   program compares, so the symbols are the reference's.
// - Lines are built in one large buffer written with write_all, and the
//   repeated sequence is written from a buffer of whole lines.

use core::arch::aarch64::*;
use std::io::Write;

const LINE: usize = 60;
const IM: u32 = 139968;
const IA: u64 = 3877;
const IC: u64 = 29573;
const FM: u64 = u64::MAX / IM as u64 + 1;
const MA: u64 = FM.wrapping_mul(IA);
const MC: u64 = FM.wrapping_mul(IC);

struct Rng(u32);

impl Rng {
    #[inline(always)]
    fn next(&mut self) -> u32 {
        let low = (self.0 as u64).wrapping_mul(MA).wrapping_add(MC);
        self.0 = ((low as u128 * IM as u128) >> 64) as u32;
        self.0
    }
}

struct Out { buf: Vec<u8> }

impl Out {
    fn put(&mut self, s: &[u8]) {
        self.buf.extend_from_slice(s);
        if self.buf.len() >= 1 << 16 { self.flush(); }
    }
    fn flush(&mut self) {
        std::io::stdout().lock().write_all(&self.buf).unwrap();
        self.buf.clear();
    }
}

fn repeat_fasta(seq: &[u8], n: usize, out: &mut Out) {
    let len = seq.len();
    // len whole lines: after len lines the text starts over at offset 0
    let mut lines = Vec::with_capacity(len * (LINE + 1));
    for i in 0..len {
        for k in 0..LINE { lines.push(seq[(i * LINE + k) % len]); }
        lines.push(b'\n');
    }
    let mut line = 0;
    for _ in 0..n / LINE {
        out.put(&lines[line * (LINE + 1)..(line + 1) * (LINE + 1)]);
        line += 1;
        if line == len { line = 0; }
    }
    let rest = n % LINE;
    if rest != 0 {
        out.put(&lines[line * (LINE + 1)..line * (LINE + 1) + rest]);
        out.put(b"\n");
    }
}

fn random_fasta(table: &[(u8, f64)], n: usize, rng: &mut Rng, out: &mut Out) {
    let symb: Vec<u8> = table.iter().map(|&(c, _)| c).collect();
    let mut t = [u32::MAX; 16];
    let mut p = 0.0;
    for j in 0..table.len() - 1 {
        p = if j == 0 { table[0].1 } else { table[j].1 + p };
        let mut s = (p * IM as f64) as u32;
        while s > 0 && (s - 1) as f64 / IM as f64 > p { s -= 1; }
        while !(s as f64 / IM as f64 > p) { s += 1; }
        t[j] = s;
    }
    let quads = (table.len() - 1 + 3) / 4;
    let tv: [uint32x4_t; 4] = unsafe { core::array::from_fn(|j| vld1q_u32(t.as_ptr().add(4 * j))) };
    let lookup = |s: u32| -> usize {
        unsafe {
            let sv = vdupq_n_u32(s);
            let mut count = vdupq_n_u32(0);
            for j in 0..quads { count = vsubq_u32(count, vcgeq_u32(sv, tv[j])); }
            vaddvq_u32(count) as usize
        }
    };

    let mut line = [b'\n'; LINE + 1];
    let mut i = 0;
    while i + LINE <= n {
        for k in 0..LINE { line[k] = unsafe { *symb.get_unchecked(lookup(rng.next())) }; }
        out.put(&line);
        i += LINE;
    }
    if i < n {
        let k = n - i;
        for c in &mut line[..k] { *c = unsafe { *symb.get_unchecked(lookup(rng.next())) }; }
        line[k] = b'\n';
        out.put(&line[..k + 1]);
    }
}

fn main() {
    let n = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(1000);
    const ALU: &[u8] =
        b"GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGA\
          TCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACT\
          AAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAG\
          GCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCG\
          CCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";
    let iub = [(b'a', 0.27), (b'c', 0.12), (b'g', 0.12), (b't', 0.27), (b'B', 0.02),
               (b'D', 0.02), (b'H', 0.02), (b'K', 0.02), (b'M', 0.02), (b'N', 0.02),
               (b'R', 0.02), (b'S', 0.02), (b'V', 0.02), (b'W', 0.02), (b'Y', 0.02)];
    let homosapiens = [(b'a', 0.3029549426680), (b'c', 0.1979883004921),
                       (b'g', 0.1975473066391), (b't', 0.3015094502008)];

    let mut out = Out { buf: Vec::with_capacity(1 << 17) };
    let mut rng = Rng(42);
    out.put(b">ONE Homo sapiens alu\n");
    repeat_fasta(ALU, n * 2, &mut out);
    out.put(b">TWO IUB ambiguity codes\n");
    random_fasta(&iub, n * 3, &mut rng, &mut out);
    out.put(b">THREE Homo sapiens frequency\n");
    random_fasta(&homosapiens, n * 5, &mut rng, &mut out);
    out.flush();
}
