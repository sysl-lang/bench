// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by Renat Galimov
//
// Tuned for this suite. The counting is the same: every k-mer of the third
// sequence counted in std's HashMap keyed by its 2k-bit code, with a
// one-multiply hasher. What is faster:
// - k-mers of up to 16 bases are counted in a map with u32 keys and u32
//   counts (eight bytes per slot instead of sixteen); only the 18-mers need
//   u64 keys;
// - every map is created with a capacity hint, so it never rehashes while
//   counting;
// - standard input is read whole and the sequence lines are joined and
//   encoded in one pass (the plain program upper-cases a String per line).
// Single-threaded: the seven counts run one after another.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hash, Hasher};
use std::io::{Read, Write};

// One multiply; the high bits feed the table's index and control bytes.
#[derive(Default)]
struct KmerHasher(u64);

impl Hasher for KmerHasher {
    #[inline(always)]
    fn finish(&self) -> u64 { self.0 }
    fn write(&mut self, _: &[u8]) { unreachable!() }
    #[inline(always)]
    fn write_u32(&mut self, key: u32) { self.0 = (key as u64).wrapping_mul(0x9E3779B97F4A7C15); }
    #[inline(always)]
    fn write_u64(&mut self, key: u64) { self.0 = key.wrapping_mul(0x9E3779B97F4A7C15); }
}

type Counts<K> = HashMap<K, u32, BuildHasherDefault<KmerHasher>>;

trait Key: Copy + Eq + Hash {
    fn from_u64(v: u64) -> Self;
}
impl Key for u32 {
    fn from_u64(v: u64) -> u32 { v as u32 }
}
impl Key for u64 {
    fn from_u64(v: u64) -> u64 { v }
}

// Counts every k-mer of the sequence (codes 0..=3) under its 2k-bit code.
fn count<K: Key>(seq: &[u8], k: usize) -> Counts<K> {
    let distinct = if k < 16 { 1usize << (2 * k) } else { usize::MAX };
    let hint = distinct.min(seq.len()).min(1 << 20);
    let mut counts = Counts::<K>::with_capacity_and_hasher(hint, Default::default());
    if seq.len() < k { return counts; }
    let mask = if k == 32 { !0 } else { (1u64 << (2 * k)) - 1 };
    let mut key = 0u64;
    for &b in &seq[..k - 1] { key = (key << 2) | b as u64; }
    for &b in &seq[k - 1..] {
        key = ((key << 2) | b as u64) & mask;
        *counts.entry(K::from_u64(key)).or_insert(0) += 1;
    }
    counts
}

fn name_of(key: u64, k: usize) -> String {
    (0..k).map(|i| b"ACGT"[((key >> (2 * (k - 1 - i))) & 3) as usize] as char).collect()
}

fn percents(seq: &[u8], k: usize, out: &mut Vec<u8>) {
    let counts = count::<u32>(seq, k);
    let total: u32 = counts.values().sum();
    let mut items: Vec<(u32, u32)> = counts.into_iter().collect();
    // count descending, then by name, which for equal lengths is key order
    items.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    for (key, c) in items {
        writeln!(out, "{} {:.3}", name_of(key as u64, k), (c * 100) as f64 / total as f64).unwrap();
    }
    writeln!(out).unwrap();
}

fn count_of(seq: &[u8], pattern: &str, out: &mut Vec<u8>) {
    let want = pattern.bytes().fold(0u64, |key, b| (key << 2) | code(b) as u64);
    let k = pattern.len();
    let c = if k <= 16 {
        count::<u32>(seq, k).get(&(want as u32)).copied()
    } else {
        count::<u64>(seq, k).get(&want).copied()
    };
    writeln!(out, "{}\t{}", c.unwrap_or(0), pattern).unwrap();
}

#[inline(always)]
fn code(b: u8) -> u8 {
    // A=0 C=1 G=2 T=3 from the low three bits, either case
    b"\x00\x00\x00\x01\x03\x00\x00\x02"[(b & 7) as usize]
}

fn main() {
    let mut input = Vec::new();
    std::io::stdin().lock().read_to_end(&mut input).unwrap();

    // the line after ">THREE", up to the next '>'
    let start = input.windows(6).position(|w| w == b">THREE").expect("no >THREE");
    let body = start + input[start..].iter().position(|&b| b == b'\n').map_or(input.len() - start, |p| p + 1);
    let mut seq = Vec::with_capacity(input.len() - body);
    for &b in &input[body..] {
        if b == b'>' { break; }
        if b != b'\n' { seq.push(code(b)); }
    }

    let mut out = Vec::new();
    percents(&seq, 1, &mut out);
    percents(&seq, 2, &mut out);
    for p in ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"] {
        count_of(&seq, p, &mut out);
    }
    std::io::stdout().lock().write_all(&out).unwrap();
}
