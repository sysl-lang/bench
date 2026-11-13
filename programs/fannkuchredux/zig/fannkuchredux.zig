// The Computer Language Benchmarks Game: fannkuch-redux. Same algorithm as the C version
// (Tompkin-Paige iterative permutation generation).
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;

var s: [16]i32 = undefined;
var t: [16]i32 = undefined;

var maxflips: i32 = 0;
var max_n: usize = 0;
var odd = false;
var checksum: i32 = 0;

fn flip() i32 {
    for (0..max_n) |k| t[k] = s[k];
    var i: i32 = 1;
    while (true) {
        var x: usize = 0;
        var y: usize = @intCast(t[0]);
        while (x < y) {
            const c = t[x];
            t[x] = t[y];
            t[y] = c;
            x += 1;
            y -= 1;
        }
        i += 1;
        if (t[@intCast(t[0])] == 0) break;
    }
    return i;
}

inline fn rotate(n: usize) void {
    const c = s[0];
    var i: usize = 1;
    while (i <= n) : (i += 1) s[i - 1] = s[i];
    s[n] = c;
}

fn tk(n: usize) void {
    var i: usize = 0;
    var c: [16]i32 = @splat(0);
    while (i < n) {
        rotate(i);
        if (c[i] >= i) {
            c[i] = 0;
            i += 1;
            continue;
        }
        c[i] += 1;
        i = 1;
        odd = !odd;
        if (s[0] != 0) {
            const f: i32 = if (s[@intCast(s[0])] != 0) flip() else 1;
            if (f > maxflips) maxflips = f;
            checksum += if (odd) -f else f;
        }
    }
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    if (argc < 2) return 1;
    const n = atoi(argv[1]);
    if (n < 3 or n > 15) return 1;
    max_n = @intCast(n);
    for (0..max_n) |i| s[i] = @intCast(i);
    tk(max_n);
    _ = printf("%d\nPfannkuchen(%d) = %d\n", checksum, n, maxflips);
    return 0;
}
