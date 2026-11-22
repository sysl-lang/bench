// Upstream C++ nbody.h. C++'s getters and setters are field accesses here: Rust's idiom for a plain
// data struct, and what the inlined C++ accessors compile to. Rust never contracts a multiply and an
// add into a fused one, as C++'s -ffp-contract=off asks, so the energy matches bit for bit.

use crate::benchmark::Benchmark;

const PI: f64 = 3.141592653589793;
const SOLAR_MASS: f64 = 4.0 * PI * PI;
const DAYS_PER_YER: f64 = 365.24;

#[derive(Clone, Copy)]
struct Body {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    mass: f64,
}

impl Body {
    fn new(x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, mass: f64) -> Body {
        Body {
            x,
            y,
            z,
            vx: vx * DAYS_PER_YER,
            vy: vy * DAYS_PER_YER,
            vz: vz * DAYS_PER_YER,
            mass: mass * SOLAR_MASS,
        }
    }

    fn offset_momentum(&mut self, px: f64, py: f64, pz: f64) {
        self.vx = 0.0 - (px / SOLAR_MASS);
        self.vy = 0.0 - (py / SOLAR_MASS);
        self.vz = 0.0 - (pz / SOLAR_MASS);
    }

    fn jupiter() -> Body {
        Body::new(
            4.84143144246472090e+00,
            -1.16032004402742839e+00,
            -1.03622044471123109e-01,
            1.66007664274403694e-03,
            7.69901118419740425e-03,
            -6.90460016972063023e-05,
            9.54791938424326609e-04,
        )
    }

    fn saturn() -> Body {
        Body::new(
            8.34336671824457987e+00,
            4.12479856412430479e+00,
            -4.03523417114321381e-01,
            -2.76742510726862411e-03,
            4.99852801234917238e-03,
            2.30417297573763929e-05,
            2.85885980666130812e-04,
        )
    }

    fn uranus() -> Body {
        Body::new(
            1.28943695621391310e+01,
            -1.51111514016986312e+01,
            -2.23307578892655734e-01,
            2.96460137564761618e-03,
            2.37847173959480950e-03,
            -2.96589568540237556e-05,
            4.36624404335156298e-05,
        )
    }

    fn neptune() -> Body {
        Body::new(
            1.53796971148509165e+01,
            -2.59193146099879641e+01,
            1.79258772950371181e-01,
            2.68067772490389322e-03,
            1.62824170038242295e-03,
            -9.51592254519715870e-05,
            5.15138902046611451e-05,
        )
    }

    fn sun() -> Body {
        Body::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0)
    }
}

struct NBodySystem {
    bodies_size: usize,
    bodies: [Body; 5],
}

impl NBodySystem {
    fn new() -> NBodySystem {
        let bodies_size = 5;
        NBodySystem { bodies_size, bodies: NBodySystem::create_bodies(bodies_size) }
    }

    fn create_bodies(bodies_size: usize) -> [Body; 5] {
        let mut bodies = [Body::sun(), Body::jupiter(), Body::saturn(), Body::uranus(), Body::neptune()];

        let mut px = 0.0;
        let mut py = 0.0;
        let mut pz = 0.0;

        for b in &bodies[..bodies_size] {
            px += b.vx * b.mass;
            py += b.vy * b.mass;
            pz += b.vz * b.mass;
        }

        bodies[0].offset_momentum(px, py, pz);

        bodies
    }

    fn advance(&mut self, dt: f64) {
        for i in 0..self.bodies_size {
            let (head, rest) = self.bodies[..self.bodies_size].split_at_mut(i + 1);
            let i_body = &mut head[i];

            for j_body in rest.iter_mut() {
                let dx = i_body.x - j_body.x;
                let dy = i_body.y - j_body.y;
                let dz = i_body.z - j_body.z;

                let d_squared = dx * dx + dy * dy + dz * dz;
                let distance = d_squared.sqrt();
                let mag = dt / (d_squared * distance);

                i_body.vx -= dx * j_body.mass * mag;
                i_body.vy -= dy * j_body.mass * mag;
                i_body.vz -= dz * j_body.mass * mag;

                j_body.vx += dx * i_body.mass * mag;
                j_body.vy += dy * i_body.mass * mag;
                j_body.vz += dz * i_body.mass * mag;
            }
        }

        for body in &mut self.bodies[..self.bodies_size] {
            body.x += dt * body.vx;
            body.y += dt * body.vy;
            body.z += dt * body.vz;
        }
    }

    fn energy(&self) -> f64 {
        let mut e = 0.0;

        for i in 0..self.bodies_size {
            let i_body = &self.bodies[i];
            e += 0.5 * i_body.mass * (i_body.vx * i_body.vx + i_body.vy * i_body.vy + i_body.vz * i_body.vz);

            for j_body in &self.bodies[i + 1..self.bodies_size] {
                let dx = i_body.x - j_body.x;
                let dy = i_body.y - j_body.y;
                let dz = i_body.z - j_body.z;

                let distance = (dx * dx + dy * dy + dz * dz).sqrt();
                e -= (i_body.mass * j_body.mass) / distance;
            }
        }
        e
    }
}

pub struct NBody;

impl NBody {
    fn verify(&self, result: f64, inner_iterations: i32) -> bool {
        if inner_iterations == 250000 {
            return result == -0.1690859889909308;
        }
        if inner_iterations == 1 {
            return result == -0.16907495402506745;
        }

        println!("No verification result for {inner_iterations} found");
        println!("Result is: {result}");
        false
    }
}

impl Benchmark for NBody {
    type Result = ();

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        let mut system = NBodySystem::new();
        for _ in 0..inner_iterations {
            system.advance(0.01);
        }

        self.verify(system.energy(), inner_iterations)
    }

    fn benchmark(&mut self) {
        unreachable!("Should never be reached");
    }

    fn verify_result(&mut self, _result: ()) -> bool {
        unreachable!("Should never be reached");
    }
}
