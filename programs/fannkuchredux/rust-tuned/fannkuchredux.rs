// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by TeXitoi
//
// Tuned for this suite: the permutation is one 16-byte NEON register
// (core::arch::aarch64). Flipping the first k+1 elements is one table lookup
// (TBL) through a precomputed reversal mask chosen at run time by k, and the
// rotation that steps to the next permutation is one TBL through a
// precomputed rotation mask. The permutations are visited in the same
// lexicographic order as the plain program (a count array), and each is
// flipped until 0 (1 in the puzzle's numbering) leads.

use core::arch::aarch64::*;

fn fannkuch(n: usize) -> (i32, i32) {
    let mut rev_mask = [[0u8; 16]; 16];
    let mut rot_mask = [[0u8; 16]; 16];
    for k in 0..16 {
        for i in 0..16 {
            rev_mask[k][i] = if i <= k { (k - i) as u8 } else { i as u8 };
            rot_mask[k][i] = if i < k { (i + 1) as u8 } else if i == k { 0 } else { i as u8 };
        }
    }
    let ident: [u8; 16] = core::array::from_fn(|i| i as u8);
    let mut count = [0usize; 16];
    let (mut maxflips, mut checksum, mut odd) = (0, 0, false);

    unsafe {
        let mut perm = vld1q_u8(ident.as_ptr());
        loop {
            let mut first = vgetq_lane_u8::<0>(perm) as usize;
            if first != 0 {
                let mut t = perm;
                let mut flips = 0;
                loop {
                    t = vqtbl1q_u8(t, vld1q_u8(rev_mask.get_unchecked(first).as_ptr()));
                    flips += 1;
                    first = vgetq_lane_u8::<0>(t) as usize;
                    if first == 0 { break; }
                }
                if flips > maxflips { maxflips = flips; }
                checksum += if odd { -flips } else { flips };
            }
            // next permutation: rotate the first i+1 until a counter can advance
            let mut i = 1;
            loop {
                if i >= n { return (checksum, maxflips); }
                perm = vqtbl1q_u8(perm, vld1q_u8(rot_mask.get_unchecked(i).as_ptr()));
                let c = count.get_unchecked_mut(i);
                if *c < i { *c += 1; break; }
                *c = 0;
                i += 1;
            }
            odd = !odd;
        }
    }
}

fn main() {
    let n = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(7);
    let (checksum, maxflips) = fannkuch(n);
    println!("{}\nPfannkuchen({}) = {}", checksum, n, maxflips);
}
