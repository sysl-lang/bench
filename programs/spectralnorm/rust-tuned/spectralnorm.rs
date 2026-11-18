// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by TeXitoi
//
// Tuned for this suite: eight columns per step in four NEON two-lane
// vectors (core::arch::aarch64), each denominator computed exactly in f64
// from the column index vector, four independent sums so the divides
// overlap, and unchecked loads. Same work: every A[i][j] computed on the
// fly and divided into.

use core::arch::aarch64::*;

fn main() {
    let n = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(100);
    println!("{:.9}", spectralnorm(n));
}

fn spectralnorm(n: usize) -> f64 {
    let mut u = vec![1.0; n];
    let mut v = vec![0.0; n];
    let mut tmp = vec![0.0; n];
    for _ in 0..10 {
        mult_at_av(&u, &mut v, &mut tmp);
        mult_at_av(&v, &mut u, &mut tmp);
    }
    (dot(&u, &v) / dot(&v, &v)).sqrt()
}

fn mult_at_av(v: &[f64], out: &mut [f64], tmp: &mut [f64]) {
    mult::<false>(v, tmp);
    mult::<true>(tmp, out);
}

// out[i] = sum_j A[i][j] v[j], or A[j][i] when TRANSPOSE.
#[inline(always)]
fn mult<const TRANSPOSE: bool>(v: &[f64], out: &mut [f64]) {
    let n = v.len();
    assert!(out.len() == n);
    for i in 0..n {
        let mut sum;
        let mut j = 0;
        unsafe {
            let iv = vdupq_n_f64(i as f64);
            let one = vdupq_n_f64(1.0);
            let half = vdupq_n_f64(0.5);
            let two = vdupq_n_f64(2.0);
            let eight = vdupq_n_f64(8.0);
            let mut j0 = vcombine_f64(vcreate_f64(0f64.to_bits()), vcreate_f64(1f64.to_bits()));
            let mut s0 = vdupq_n_f64(0.0);
            let mut s1 = s0;
            let mut s2 = s0;
            let mut s3 = s0;
            let p = v.as_ptr();
            while j + 8 <= n {
                let ja = j0;
                let jb = vaddq_f64(ja, two);
                let jc = vaddq_f64(jb, two);
                let jd = vaddq_f64(jc, two);
                let den = |jv: float64x2_t| {
                    let s = vaddq_f64(iv, jv);
                    let e = if TRANSPOSE { jv } else { iv };
                    // exact: every value is an integer below 2^53
                    vfmaq_f64(vaddq_f64(e, one), vmulq_f64(s, vaddq_f64(s, one)), half)
                };
                s0 = vaddq_f64(s0, vdivq_f64(vld1q_f64(p.add(j)), den(ja)));
                s1 = vaddq_f64(s1, vdivq_f64(vld1q_f64(p.add(j + 2)), den(jb)));
                s2 = vaddq_f64(s2, vdivq_f64(vld1q_f64(p.add(j + 4)), den(jc)));
                s3 = vaddq_f64(s3, vdivq_f64(vld1q_f64(p.add(j + 6)), den(jd)));
                j0 = vaddq_f64(j0, eight);
                j += 8;
            }
            sum = vaddvq_f64(vaddq_f64(vaddq_f64(s0, s1), vaddq_f64(s2, s3)));
        }
        while j < n {
            let s = i + j;
            let e = if TRANSPOSE { j } else { i };
            sum += v[j] / ((s * (s + 1) / 2 + e + 1) as f64);
            j += 1;
        }
        unsafe { *out.get_unchecked_mut(i) = sum; }
    }
}

fn dot(v: &[f64], u: &[f64]) -> f64 {
    v.iter().zip(u.iter()).map(|(a, b)| *a * *b).fold(0., |acc, i| acc + i)
}
