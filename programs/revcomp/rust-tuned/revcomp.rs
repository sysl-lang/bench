// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by Cristi Cobzarenco
// contributed by TeXitoi
// contributed by Matt Brubeck
//
// Tuned for this suite: standard input is read whole and the output written
// with one write_all. Each record's sequence lines are joined (newlines found
// sixteen bytes at a time with NEON), then reverse-complemented sixteen bytes
// at a time from both ends with NEON (core::arch::aarch64): the complement is
// a table of the 32 codes indexed by the low five bits of the letter (upper
// and lower case share it), looked up with one two-register TBL, and the
// reversal is a REV64 plus a swap of halves. The result is re-wrapped at 60.
// Same work: each record read whole, complemented through a table, reversed
// and re-wrapped at 60.

use core::arch::aarch64::*;
use std::io::{Read, Write};

const COMP: &[u8; 32] = b"\0TVGH\0\0CD\0\0M\0KN\0\0\0YSA\0BW\0R\0\0\0\0\0\0";

// Index of the first `b` in `s`, or `s.len()`.
#[inline]
fn find(s: &[u8], b: u8) -> usize {
    let mut i = 0;
    unsafe {
        let needle = vdupq_n_u8(b);
        while i + 16 <= s.len() {
            let eq = vceqq_u8(vld1q_u8(s.as_ptr().add(i)), needle);
            if vmaxvq_u8(eq) != 0 {
                // narrow to a 64-bit mask, four bits per byte
                let m = vget_lane_u64::<0>(vreinterpret_u64_u8(vshrn_n_u16::<4>(vreinterpretq_u16_u8(eq))));
                return i + (m.trailing_zeros() / 4) as usize;
            }
            i += 16;
        }
    }
    while i < s.len() && s[i] != b { i += 1; }
    i
}

#[inline(always)]
unsafe fn revcomp16(v: uint8x16_t, tab: uint8x16x2_t) -> uint8x16_t {
    let c = vqtbl2q_u8(tab, vandq_u8(v, vdupq_n_u8(31)));
    let c = vrev64q_u8(c);
    vextq_u8::<8>(c, c)
}

fn reverse_complement(s: &mut [u8]) {
    let (mut lo, mut hi) = (0, s.len());
    unsafe {
        let tab = uint8x16x2_t(vld1q_u8(COMP.as_ptr()), vld1q_u8(COMP.as_ptr().add(16)));
        let p = s.as_mut_ptr();
        while hi - lo >= 32 {
            let a = vld1q_u8(p.add(lo));
            let b = vld1q_u8(p.add(hi - 16));
            vst1q_u8(p.add(lo), revcomp16(b, tab));
            vst1q_u8(p.add(hi - 16), revcomp16(a, tab));
            lo += 16;
            hi -= 16;
        }
    }
    while hi - lo >= 2 {
        hi -= 1;
        let (a, b) = (s[lo], s[hi]);
        s[lo] = COMP[(b & 31) as usize];
        s[hi] = COMP[(a & 31) as usize];
        lo += 1;
    }
    if lo < hi { s[lo] = COMP[(s[lo] & 31) as usize]; }
}

fn main() {
    let mut input = Vec::with_capacity(1 << 24);
    std::io::stdin().lock().read_to_end(&mut input).unwrap();
    let len = input.len();
    let mut out = Vec::with_capacity(len + len / 60 + 64);
    let mut seq = Vec::with_capacity(len);

    let mut i = 0;
    while i < len {
        // header line, copied as it is
        let hend = (i + find(&input[i..], b'\n') + 1).min(len);
        out.extend_from_slice(&input[i..hend]);
        i = hend;

        // sequence lines up to the next '>' joined into seq
        let send = i + find(&input[i..], b'>');
        seq.clear();
        while i < send {
            let lend = i + find(&input[i..send], b'\n');
            seq.extend_from_slice(&input[i..lend]);
            i = lend + 1;
        }
        i = i.min(send);

        reverse_complement(&mut seq);

        for line in seq.chunks(60) {
            out.extend_from_slice(line);
            out.push(b'\n');
        }
    }
    std::io::stdout().lock().write_all(&out).unwrap();
}
