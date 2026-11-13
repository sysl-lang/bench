// The Computer Language Benchmarks Game: n-body. Same algorithm as the C version.
// The C library supplies argument parsing and output, as in the C program.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;

const pi = 3.141592653589793;
const solar_mass = 4.0 * pi * pi;
const days_per_year = 365.24;

const Planet = struct {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    mass: f64,
};

const NBODIES = 5;

var bodies = [NBODIES]Planet{
    .{ .x = 0, .y = 0, .z = 0, .vx = 0, .vy = 0, .vz = 0, .mass = solar_mass },
    .{
        .x = 4.84143144246472090e+00,
        .y = -1.16032004402742839e+00,
        .z = -1.03622044471123109e-01,
        .vx = 1.66007664274403694e-03 * days_per_year,
        .vy = 7.69901118419740425e-03 * days_per_year,
        .vz = -6.90460016972063023e-05 * days_per_year,
        .mass = 9.54791938424326609e-04 * solar_mass,
    },
    .{
        .x = 8.34336671824457987e+00,
        .y = 4.12479856412430479e+00,
        .z = -4.03523417114321381e-01,
        .vx = -2.76742510726862411e-03 * days_per_year,
        .vy = 4.99852801234917238e-03 * days_per_year,
        .vz = 2.30417297573763929e-05 * days_per_year,
        .mass = 2.85885980666130812e-04 * solar_mass,
    },
    .{
        .x = 1.28943695621391310e+01,
        .y = -1.51111514016986312e+01,
        .z = -2.23307578892655734e-01,
        .vx = 2.96460137564761618e-03 * days_per_year,
        .vy = 2.37847173959480950e-03 * days_per_year,
        .vz = -2.96589568540237556e-05 * days_per_year,
        .mass = 4.36624404335156298e-05 * solar_mass,
    },
    .{
        .x = 1.53796971148509165e+01,
        .y = -2.59193146099879641e+01,
        .z = 1.79258772950371181e-01,
        .vx = 2.68067772490389322e-03 * days_per_year,
        .vy = 1.62824170038242295e-03 * days_per_year,
        .vz = -9.51592254519715870e-05 * days_per_year,
        .mass = 5.15138902046611451e-05 * solar_mass,
    },
};

fn advance(dt: f64) void {
    var i: usize = 0;
    while (i < NBODIES) : (i += 1) {
        const b = &bodies[i];
        var j: usize = i + 1;
        while (j < NBODIES) : (j += 1) {
            const b2 = &bodies[j];
            const dx = b.x - b2.x;
            const dy = b.y - b2.y;
            const dz = b.z - b2.z;
            const distanced = dx * dx + dy * dy + dz * dz;
            const distance = @sqrt(distanced);
            const mag = dt / (distanced * distance);
            b.vx -= dx * b2.mass * mag;
            b.vy -= dy * b2.mass * mag;
            b.vz -= dz * b2.mass * mag;
            b2.vx += dx * b.mass * mag;
            b2.vy += dy * b.mass * mag;
            b2.vz += dz * b.mass * mag;
        }
    }
    i = 0;
    while (i < NBODIES) : (i += 1) {
        const b = &bodies[i];
        b.x += dt * b.vx;
        b.y += dt * b.vy;
        b.z += dt * b.vz;
    }
}

fn energy() f64 {
    var e: f64 = 0.0;
    var i: usize = 0;
    while (i < NBODIES) : (i += 1) {
        const b = &bodies[i];
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
        var j: usize = i + 1;
        while (j < NBODIES) : (j += 1) {
            const b2 = &bodies[j];
            const dx = b.x - b2.x;
            const dy = b.y - b2.y;
            const dz = b.z - b2.z;
            const distance = @sqrt(dx * dx + dy * dy + dz * dz);
            e -= (b.mass * b2.mass) / distance;
        }
    }
    return e;
}

fn offsetMomentum() void {
    var px: f64 = 0.0;
    var py: f64 = 0.0;
    var pz: f64 = 0.0;
    for (bodies) |b| {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    bodies[0].vx = -px / solar_mass;
    bodies[0].vy = -py / solar_mass;
    bodies[0].vz = -pz / solar_mass;
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const n = atoi(argv[1]);
    offsetMomentum();
    _ = printf("%.9f\n", energy());
    var i: c_int = 1;
    while (i <= n) : (i += 1) advance(0.01);
    _ = printf("%.9f\n", energy());
    return 0;
}
