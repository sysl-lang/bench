// The Computer Language Benchmarks Game: mandelbrot. Same algorithm as the C version.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn putchar(c: c_int) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const w: c_int = atoi(argv[1]);
    const h = w;
    const iter = 50;
    const limit: f64 = 2.0;
    var bit_num: c_int = 0;
    var byte_acc: u8 = 0;

    _ = printf("P4\n%d %d\n", w, h);

    const wf: f64 = @floatFromInt(w);
    const hf: f64 = @floatFromInt(h);
    var y: f64 = 0;
    while (y < hf) : (y += 1) {
        var x: f64 = 0;
        while (x < wf) : (x += 1) {
            var Zr: f64 = 0;
            var Zi: f64 = 0;
            var Tr: f64 = 0;
            var Ti: f64 = 0;
            const Cr = 2.0 * x / wf - 1.5;
            const Ci = 2.0 * y / hf - 1.0;

            var i: c_int = 0;
            while (i < iter and (Tr + Ti <= limit * limit)) : (i += 1) {
                Zi = 2.0 * Zr * Zi + Ci;
                Zr = Tr - Ti + Cr;
                Tr = Zr * Zr;
                Ti = Zi * Zi;
            }

            byte_acc <<= 1;
            if (Tr + Ti <= limit * limit) byte_acc |= 0x01;
            bit_num += 1;

            if (bit_num == 8) {
                _ = putchar(byte_acc);
                byte_acc = 0;
                bit_num = 0;
            } else if (x == wf - 1) {
                byte_acc <<= @intCast(8 - @mod(w, 8));
                _ = putchar(byte_acc);
                byte_acc = 0;
                bit_num = 0;
            }
        }
    }
    return 0;
}
