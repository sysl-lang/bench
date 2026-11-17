// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by Matt Watson
// contributed by TeXitoi
//
// Tuned for this suite: two output bytes (sixteen pixels) per pass as eight
// independent NEON two-lane chains (core::arch::aarch64), so the
// floating-point pipes stay busy; the initial real parts precomputed per
// column; the escape test made every fifth iteration instead of every one (a
// pixel that has escaped only grows, or overflows to inf/NaN, which fail
// `<= 4` too, so the extra iterations cannot bring it back and the image is
// the same); the image written with one write_all. Same work: up to 50
// iterations per pixel, bits packed eight to a byte.

use core::arch::aarch64::*;
use std::io::Write;

const CHAINS: usize = 8; // eight float64x2 = sixteen pixels = two bytes

#[inline(always)]
unsafe fn octets(cr: &[f64], ci: f64) -> [u8; 2] {
    let civ = vdupq_n_f64(ci);
    let four = vdupq_n_f64(4.0);
    let zero = vdupq_n_f64(0.0);
    let mut c = [zero; CHAINS];
    for k in 0..CHAINS { c[k] = vld1q_f64(cr.as_ptr().add(2 * k)); }
    let mut zr = [zero; CHAINS];
    let mut zi = [zero; CHAINS];
    let mut tr = [zero; CHAINS];
    let mut ti = [zero; CHAINS];
    for _ in 0..10 {
        let mut any = vdupq_n_u64(0);
        for k in 0..CHAINS {
            any = vorrq_u64(any, vcleq_f64(vaddq_f64(tr[k], ti[k]), four));
        }
        if vmaxvq_u32(vreinterpretq_u32_u64(any)) == 0 { break; }
        for _ in 0..5 {
            for k in 0..CHAINS {
                let zr2 = vaddq_f64(zr[k], zr[k]);
                zi[k] = vaddq_f64(vmulq_f64(zr2, zi[k]), civ);
                zr[k] = vaddq_f64(vsubq_f64(tr[k], ti[k]), c[k]);
                tr[k] = vmulq_f64(zr[k], zr[k]);
                ti[k] = vmulq_f64(zi[k], zi[k]);
            }
        }
    }
    let mut out = [0u8; 2];
    for k in 0..CHAINS {
        let inside = vcleq_f64(vaddq_f64(tr[k], ti[k]), four);
        let hi = (vgetq_lane_u64::<0>(inside) & 1) as u8;
        let lo = (vgetq_lane_u64::<1>(inside) & 1) as u8;
        let shift = 6 - 2 * (k % 4);
        out[k / 4] |= (hi << (shift + 1)) | (lo << shift);
    }
    out
}

fn main() {
    let n: usize = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(200);
    let bytes = (n + 7) / 8;
    let cols = (bytes + 1) / 2 * 16;
    let cr: Vec<f64> = (0..cols).map(|x| 2.0 * x as f64 / n as f64 - 1.5).collect();
    let mut image = vec![0u8; bytes * n];

    for (y, row) in image.chunks_exact_mut(bytes).enumerate() {
        let ci = 2.0 * y as f64 / n as f64 - 1.0;
        let mut b = 0;
        while b < bytes {
            let pair = unsafe { octets(cr.get_unchecked(8 * b..8 * b + 16), ci) };
            row[b] = pair[0];
            if b + 1 < bytes { row[b + 1] = pair[1]; }
            b += 2;
        }
        if n % 8 != 0 { row[bytes - 1] &= (0xFFu32 << (8 - n % 8)) as u8; }
    }

    let out = std::io::stdout();
    let mut out = out.lock();
    write!(out, "P4\n{} {}\n", n, n).unwrap();
    out.write_all(&image).unwrap();
}
