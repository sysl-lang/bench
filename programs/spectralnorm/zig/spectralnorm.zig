// The Computer Language Benchmarks Game: spectral norm. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (spectralnorm.gcc-3, Mr Ledrug): ten rounds
// of A then A transposed applied to a vector, each term u[j] / A's integer denominator, computed on
// the fly; each product's rows split into one contiguous range per core, as the C program's
// `omp parallel for` splits them. Each row is summed in the C program's order, so the result does not
// depend on the thread count.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn malloc(n: usize) ?*anyopaque;

// The denominator of A(i, j) = 1 / ((i + j)(i + j + 1)/2 + i + 1), as an int, as the C program has it.
inline fn a(i: usize, j: usize) f64 {
    const ii: i32 = @intCast(i);
    const jj: i32 = @intCast(j);
    return @floatFromInt(@divTrunc((ii + jj) * (ii + jj + 1), 2) + ii + 1);
}

fn rowsATimesU(u: []const f64, au: []f64, first: usize, last: usize) void {
    for (first..last) |i| {
        var sum: f64 = 0;
        for (u, 0..) |uj, j| sum += uj / a(i, j);
        au[i] = sum;
    }
}

fn rowsAtTimesU(u: []const f64, au: []f64, first: usize, last: usize) void {
    for (first..last) |i| {
        var sum: f64 = 0;
        for (u, 0..) |uj, j| sum += uj / a(j, i);
        au[i] = sum;
    }
}

var threads_buf: [256]std.Thread = undefined;
var nthreads: usize = 1;

fn parallel(comptime f: anytype, u: []const f64, au: []f64) void {
    const n = au.len;
    const per = (n + nthreads - 1) / nthreads;
    var spawned: usize = 0;
    var first: usize = per;
    while (first < n) : (first += per) {
        threads_buf[spawned] = std.Thread.spawn(.{}, f, .{ u, au, first, @min(first + per, n) }) catch unreachable;
        spawned += 1;
    }
    f(u, au, 0, @min(per, n));
    for (threads_buf[0..spawned]) |*t| t.join();
}

fn evalAtATimesU(u: []const f64, atau: []f64, v: []f64) void {
    parallel(rowsATimesU, u, v);
    parallel(rowsAtTimesU, v, atau);
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    const n: usize = if (argc == 2) @intCast(atoi(argv[1])) else 100;
    nthreads = @min(threads_buf.len, std.Thread.getCpuCount() catch 1);
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
