// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by Renat Galimov
//
// Adapted for this suite: the thread per k-mer length is replaced by a sequential loop.


use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};
use std::vec::Vec;
use std::string::String;


// A hasher for the integer k-mer keys: one multiply, as the C program's khash does.
#[derive(Default)]
struct KmerHasher(u64);

impl Hasher for KmerHasher {
    fn finish(&self) -> u64 {
        self.0
    }
    fn write(&mut self, _: &[u8]) {
        unreachable!()
    }
    fn write_u64(&mut self, key: u64) {
        self.0 = key.wrapping_mul(0x9E3779B97F4A7C15);
    }
}

type Counts = HashMap<u64, usize, BuildHasherDefault<KmerHasher>>;

fn code_of(base: u8) -> u64 {
    match base {
        b'A' => 0,
        b'C' => 1,
        b'G' => 2,
        _ => 3,
    }
}

// Counts every k-mer of the sequence under its 2k-bit code.
fn count_nucleotides(input: &[u8], length: usize) -> Counts {
    let mut counts = Counts::default();

    if input.len() < length {
        return counts;
    }

    let mask = if length == 32 { !0 } else { (1u64 << (2 * length)) - 1 };
    let mut key = 0u64;

    for (i, &base) in input.iter().enumerate() {
        key = ((key << 2) | code_of(base)) & mask;

        if i + 1 >= length {
            *counts.entry(key).or_insert(0) += 1;
        }
    }

    counts
}

fn name_of(key: u64, length: usize) -> String {
    (0..length)
        .map(|i| b"ACGT"[((key >> (2 * (length - 1 - i))) & 3) as usize] as char)
        .collect()
}

fn read_input() -> Vec<u8> {
    let stdin = std::io::stdin();

    let mut input = String::new();

    while stdin.read_line(&mut input).unwrap() > 0 {
        if input.contains("THREE") {
            input.clear();
            break;
        }
        input.clear();
    }

    let mut data = Vec::<u8>::new();

    loop {
        let mut input = String::new();
        let bytes_read = stdin.read_line(&mut input).unwrap();

        if bytes_read == 0 {
            break
        }

        let mut input_bytes = input.to_uppercase().into_bytes();

        loop {
            match input_bytes.last() {
                Some(&b'\r') | Some(&b'\n') => { input_bytes.pop(); },
                _ => break
            }
        }

        data.append(&mut input_bytes);
    }

    data
}


fn print_percents(items: Counts, length: usize) {
    let total_count: usize = items.values().sum();
    let mut sorted_items: Vec<(u64, usize)> = items.into_iter().collect();

    sorted_items.sort_by(|a, b| b.1.cmp(&a.1).then(name_of(a.0, length).cmp(&name_of(b.0, length))));

    for item in sorted_items.iter() {
        let count = (item.1 * 100) as f64 / total_count as f64;
        println!("{} {:.3}", name_of(item.0, length), count);
    }
}

fn print_count(pattern: &str, items: Counts) {
    let key = pattern.bytes().fold(0u64, |key, base| (key << 2) | code_of(base));
    let count = items.get(&key).copied().unwrap_or(0);

    println!("{}\t{}", count, pattern);
}


fn main() {

    let data = read_input();

    let mut results = HashMap::<usize, Counts>::new();

    for k in vec![1, 2, 3, 4, 6, 12, 18] {
        results.insert(k, count_nucleotides(&data, k));
    }

    print_percents(results.remove(&1).unwrap(), 1);
    println!("");
    print_percents(results.remove(&2).unwrap(), 2);
    println!("");

    print_count("GGT", results.remove(&3).unwrap());
    print_count("GGTA", results.remove(&4).unwrap());
    print_count("GGTATT", results.remove(&6).unwrap());
    print_count("GGTATTTTAATT", results.remove(&12).unwrap());
    print_count("GGTATTTTAATTTATAGT", results.remove(&18).unwrap());
}
