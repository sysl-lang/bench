//! mandelbrot.h.

const std = @import("std");

pub const Mandelbrot = struct {
    pub fn innerBenchmarkLoop(self: *Mandelbrot, inner_iterations: i32) bool {
        return self.verifyResult(mandelbrot(inner_iterations), inner_iterations);
    }

    fn verifyResult(_: *Mandelbrot, result: i32, inner_iterations: i32) bool {
        if (inner_iterations == 500) return result == 191;
        if (inner_iterations == 750) return result == 50;
        if (inner_iterations == 1) return result == 128;

        std.debug.print("No verification result for {d} found\n", .{inner_iterations});
        std.debug.print("Result is: {d}\n", .{result});
        return false;
    }

    fn mandelbrot(size: i32) i32 {
        var sum: i32 = 0;
        var byte_acc: i32 = 0;
        var bit_num: i32 = 0;

        const fsize: f64 = @floatFromInt(size);
        var y: i32 = 0;

        while (y < size) {
            const ci = (2.0 * @as(f64, @floatFromInt(y)) / fsize) - 1.0;
            var x: i32 = 0;

            while (x < size) {
                var zrzr: f64 = 0.0;
                var zi: f64 = 0.0;
                var zizi: f64 = 0.0;
                const cr = (2.0 * @as(f64, @floatFromInt(x)) / fsize) - 1.5;

                var z: i32 = 0;
                var not_done = true;
                var escape: i32 = 0;
                while (not_done and z < 50) {
                    const zr = zrzr - zizi + cr;
                    zi = 2.0 * zr * zi + ci;

                    // preserve recalculation
                    zrzr = zr * zr;
                    zizi = zi * zi;

                    if (zrzr + zizi > 4.0) {
                        not_done = false;
                        escape = 1;
                    }
                    z += 1;
                }

                byte_acc = (byte_acc << 1) + escape;
                bit_num += 1;

                // Code is very similar for these cases, but using separate blocks
                // ensures we skip the shifting when it's unnecessary, which is most
                // cases.
                if (bit_num == 8) {
                    sum ^= byte_acc;
                    byte_acc = 0;
                    bit_num = 0;
                } else if (x == size - 1) {
                    byte_acc <<= @intCast(8 - bit_num);
                    sum ^= byte_acc;
                    byte_acc = 0;
                    bit_num = 0;
                }
                x += 1;
            }
            y += 1;
        }
        return sum;
    }
};
