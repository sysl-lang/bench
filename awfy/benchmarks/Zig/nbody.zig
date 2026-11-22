//! nbody.h. The system and its bodies live on the stack, as in C++.

const std = @import("std");

const pi = 3.141592653589793;
const solar_mass = 4 * pi * pi;
const days_per_year = 365.24;

const Body = struct {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    mass: f64,

    fn init(x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, mass: f64) Body {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .vx = vx * days_per_year,
            .vy = vy * days_per_year,
            .vz = vz * days_per_year,
            .mass = mass * solar_mass,
        };
    }

    fn offsetMomentum(self: *Body, px: f64, py: f64, pz: f64) void {
        self.vx = 0.0 - (px / solar_mass);
        self.vy = 0.0 - (py / solar_mass);
        self.vz = 0.0 - (pz / solar_mass);
    }

    fn jupiter() Body {
        return .init(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05, 9.54791938424326609e-04);
    }

    fn saturn() Body {
        return .init(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04);
    }

    fn uranus() Body {
        return .init(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05);
    }

    fn neptune() Body {
        return .init(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05, 5.15138902046611451e-05);
    }

    fn sun() Body {
        return .init(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    }
};

const NBodySystem = struct {
    bodies_size: i32 = 5,
    bodies: [5]Body,

    fn init() NBodySystem {
        var system: NBodySystem = .{ .bodies = undefined };
        system.bodies = system.createBodies();
        return system;
    }

    fn createBodies(self: *const NBodySystem) [5]Body {
        var bodies = [5]Body{ .sun(), .jupiter(), .saturn(), .uranus(), .neptune() };

        var px: f64 = 0.0;
        var py: f64 = 0.0;
        var pz: f64 = 0.0;

        const n: usize = @intCast(self.bodies_size);
        var i: usize = 0;
        while (i < n) : (i += 1) {
            px += bodies[i].vx * bodies[i].mass;
            py += bodies[i].vy * bodies[i].mass;
            pz += bodies[i].vz * bodies[i].mass;
        }

        bodies[0].offsetMomentum(px, py, pz);
        return bodies;
    }

    fn advance(self: *NBodySystem, dt: f64) void {
        const n: usize = @intCast(self.bodies_size);
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const i_body = &self.bodies[i];

            var j = i + 1;
            while (j < n) : (j += 1) {
                const j_body = &self.bodies[j];
                const dx = i_body.x - j_body.x;
                const dy = i_body.y - j_body.y;
                const dz = i_body.z - j_body.z;

                const d_squared = dx * dx + dy * dy + dz * dz;
                const distance = @sqrt(d_squared);
                const mag = dt / (d_squared * distance);

                i_body.vx = i_body.vx - (dx * j_body.mass * mag);
                i_body.vy = i_body.vy - (dy * j_body.mass * mag);
                i_body.vz = i_body.vz - (dz * j_body.mass * mag);

                j_body.vx = j_body.vx + (dx * i_body.mass * mag);
                j_body.vy = j_body.vy + (dy * i_body.mass * mag);
                j_body.vz = j_body.vz + (dz * i_body.mass * mag);
            }
        }

        i = 0;
        while (i < n) : (i += 1) {
            const body = &self.bodies[i];
            body.x = body.x + dt * body.vx;
            body.y = body.y + dt * body.vy;
            body.z = body.z + dt * body.vz;
        }
    }

    fn energy(self: *const NBodySystem) f64 {
        const n: usize = @intCast(self.bodies_size);
        var e: f64 = 0.0;

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const i_body = &self.bodies[i];
            e += 0.5 * i_body.mass *
                (i_body.vx * i_body.vx + i_body.vy * i_body.vy + i_body.vz * i_body.vz);

            var j = i + 1;
            while (j < n) : (j += 1) {
                const j_body = &self.bodies[j];
                const dx = i_body.x - j_body.x;
                const dy = i_body.y - j_body.y;
                const dz = i_body.z - j_body.z;

                const distance = @sqrt(dx * dx + dy * dy + dz * dz);
                e -= (i_body.mass * j_body.mass) / distance;
            }
        }
        return e;
    }
};

pub const NBody = struct {
    fn verifyResult(_: *NBody, result: f64, inner_iterations: i32) bool {
        if (inner_iterations == 250000) return result == -0.1690859889909308;
        if (inner_iterations == 1) return result == -0.16907495402506745;

        std.debug.print("No verification result for {d} found\n", .{inner_iterations});
        std.debug.print("Result is: {d}\n", .{result});
        return false;
    }

    pub fn innerBenchmarkLoop(self: *NBody, inner_iterations: i32) bool {
        var system: NBodySystem = .init();
        var i: i32 = 0;
        while (i < inner_iterations) : (i += 1) system.advance(0.01);

        return self.verifyResult(system.energy(), inner_iterations);
    }
};
