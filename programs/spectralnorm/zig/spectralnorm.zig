// The Computer Language Benchmarks Game: spectral norm. Same algorithm as the C version.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn malloc(n: usize) ?*anyopaque;

inline fn evalA(i: usize, j: usize) f64 {
    const ii: i32 = @intCast(i);
    const jj: i32 = @intCast(j);
    return 1.0 / @as(f64, @floatFromInt(@divTrunc((ii + jj) * (ii + jj + 1), 2) + ii + 1));
}

fn evalATimesU(u: []const f64, au: []f64) void {
    for (au, 0..) |*out, i| {
        out.* = 0;
        for (u, 0..) |uj, j| out.* += evalA(i, j) * uj;
    }
}

fn evalAtTimesU(u: []const f64, au: []f64) void {
    for (au, 0..) |*out, i| {
        out.* = 0;
        for (u, 0..) |uj, j| out.* += evalA(j, i) * uj;
    }
}

fn evalAtATimesU(u: []const f64, atau: []f64, v: []f64) void {
    evalATimesU(u, v);
    evalAtTimesU(v, atau);
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    const n: usize = if (argc == 2) @intCast(atoi(argv[1])) else 100;
    const mem: [*]f64 = @ptrCast(@alignCast(malloc(3 * n * @sizeOf(f64)).?));
    const u = mem[0..n];
    const v = mem[n .. 2 * n];
    const tmp = mem[2 * n .. 3 * n];
    for (u) |*x| x.* = 1;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        evalAtATimesU(u, v, tmp);
        evalAtATimesU(v, u, tmp);
    }
    var vBv: f64 = 0;
    var vv: f64 = 0;
    for (0..n) |k| {
        vBv += u[k] * v[k];
        vv += v[k] * v[k];
    }
    _ = printf("%0.9f\n", @sqrt(vBv / vv));
    return 0;
}
