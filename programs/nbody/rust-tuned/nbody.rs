// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by Cristi Cobzarenco
//
// Tuned for this suite: the bodies are kept as fixed arrays, one per field
// (structure of arrays), and each step first computes the ten pairwise
// differences into fixed arrays, then their distances and magnitudes as
// NEON two-lane vectors (core::arch::aarch64: five sqrt and five divide
// instructions instead of ten each), then the velocity updates. Same work:
// the pairwise advance of five bodies with an exact sqrt and divide per pair.

use core::arch::aarch64::*;

const PI: f64 = 3.141592653589793;
const SOLAR_MASS: f64 = 4.0 * PI * PI;
const YEAR: f64 = 365.24;
const N: usize = 5;
const PAIRS: usize = N * (N - 1) / 2;

struct System {
    x: [f64; N], y: [f64; N], z: [f64; N],
    vx: [f64; N], vy: [f64; N], vz: [f64; N],
    mass: [f64; N],
}

const INIT: [[f64; 7]; N] = [
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS],
    [4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
     1.66007664274403694e-03 * YEAR, 7.69901118419740425e-03 * YEAR,
     -6.90460016972063023e-05 * YEAR, 9.54791938424326609e-04 * SOLAR_MASS],
    [8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
     -2.76742510726862411e-03 * YEAR, 4.99852801234917238e-03 * YEAR,
     2.30417297573763929e-05 * YEAR, 2.85885980666130812e-04 * SOLAR_MASS],
    [1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
     2.96460137564761618e-03 * YEAR, 2.37847173959480950e-03 * YEAR,
     -2.96589568540237556e-05 * YEAR, 4.36624404335156298e-05 * SOLAR_MASS],
    [1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
     2.68067772490389322e-03 * YEAR, 1.62824170038242295e-03 * YEAR,
     -9.51592254519715870e-05 * YEAR, 5.15138902046611451e-05 * SOLAR_MASS],
];

impl System {
    fn new() -> System {
        let mut s = System { x: [0.0; N], y: [0.0; N], z: [0.0; N],
                             vx: [0.0; N], vy: [0.0; N], vz: [0.0; N], mass: [0.0; N] };
        for i in 0..N {
            let b = INIT[i];
            s.x[i] = b[0]; s.y[i] = b[1]; s.z[i] = b[2];
            s.vx[i] = b[3]; s.vy[i] = b[4]; s.vz[i] = b[5];
            s.mass[i] = b[6];
        }
        s
    }

    fn offset_momentum(&mut self) {
        let (mut px, mut py, mut pz) = (0.0, 0.0, 0.0);
        for i in 0..N {
            px += self.vx[i] * self.mass[i];
            py += self.vy[i] * self.mass[i];
            pz += self.vz[i] * self.mass[i];
        }
        self.vx[0] = -px / SOLAR_MASS;
        self.vy[0] = -py / SOLAR_MASS;
        self.vz[0] = -pz / SOLAR_MASS;
    }

    fn energy(&self) -> f64 {
        let mut e = 0.0;
        for i in 0..N {
            e += 0.5 * self.mass[i]
                * (self.vx[i] * self.vx[i] + self.vy[i] * self.vy[i] + self.vz[i] * self.vz[i]);
            for j in i + 1..N {
                let dx = self.x[i] - self.x[j];
                let dy = self.y[i] - self.y[j];
                let dz = self.z[i] - self.z[j];
                e -= (self.mass[i] * self.mass[j]) / (dx * dx + dy * dy + dz * dz).sqrt();
            }
        }
        e
    }

    fn advance(&mut self, steps: usize, dt: f64) {
        // One spare slot so the five two-lane loads stay in bounds.
        let mut dx = [0.0; PAIRS + 1];
        let mut dy = [0.0; PAIRS + 1];
        let mut dz = [0.0; PAIRS + 1];
        let mut mag = [0.0; PAIRS + 1];
        for _ in 0..steps {
            let mut k = 0;
            for i in 0..N {
                for j in i + 1..N {
                    dx[k] = self.x[i] - self.x[j];
                    dy[k] = self.y[i] - self.y[j];
                    dz[k] = self.z[i] - self.z[j];
                    k += 1;
                }
            }
            unsafe {
                let dtv = vdupq_n_f64(dt);
                let mut k = 0;
                while k < PAIRS {
                    let ax = vld1q_f64(dx.as_ptr().add(k));
                    let ay = vld1q_f64(dy.as_ptr().add(k));
                    let az = vld1q_f64(dz.as_ptr().add(k));
                    let d2 = vaddq_f64(vaddq_f64(vmulq_f64(ax, ax), vmulq_f64(ay, ay)), vmulq_f64(az, az));
                    let d = vsqrtq_f64(d2);
                    vst1q_f64(mag.as_mut_ptr().add(k), vdivq_f64(dtv, vmulq_f64(d2, d)));
                    k += 2;
                }
            }
            let mut k = 0;
            for i in 0..N {
                for j in i + 1..N {
                    let mj = self.mass[j] * mag[k];
                    let mi = self.mass[i] * mag[k];
                    self.vx[i] -= dx[k] * mj; self.vy[i] -= dy[k] * mj; self.vz[i] -= dz[k] * mj;
                    self.vx[j] += dx[k] * mi; self.vy[j] += dy[k] * mi; self.vz[j] += dz[k] * mi;
                    k += 1;
                }
            }
            for i in 0..N {
                self.x[i] += dt * self.vx[i];
                self.y[i] += dt * self.vy[i];
                self.z[i] += dt * self.vz[i];
            }
        }
    }
}

fn main() {
    let n = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(1000);
    let mut s = System::new();
    s.offset_momentum();
    println!("{:.9}", s.energy());
    s.advance(n, 0.01);
    println!("{:.9}", s.energy());
}
