// The Computer Language Benchmarks Game: mandelbrot. Original, written for this benchmark: the C
// program's per-pixel iteration (up to 50 iterations, escape when Tr + Ti > 4, coordinates
// 2*x/w - 1.5 and 2*y/h - 1.0, eight pixels to a byte). It mirrors the Game's fastest C program
// that builds here (mandelbrot.gcc-5, Ralph Ganszky and Dominic Letz: vector-extension pixels, the
// escape test every five iterations, rows spread over threads): the eight pixels of a byte are one
// @Vector(8, f64), the x coordinates are computed once, and the rows are shared out between one
// thread per core through an atomic row counter. The image is assembled in memory and written in
// one call.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn fflush(f: ?*anyopaque) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn write(fd: c_int, buf: [*]const u8, n: usize) isize;

const Image = struct {
    w: usize,
    row_bytes: usize,
    pixels: []u8,
    xs: []const V,
    next_row: std.atomic.Value(usize),
};

const V = @Vector(8, f64);

// One output byte: eight horizontally adjacent pixels iterated together, the escape test after every
// fifth iteration, as the Game's C program makes it (all eight escaped ends the byte early; an
// escaped pixel only grows, or overflows to inf/NaN, which fail `<= 4` too).
fn byteAt(cr: V, ci: V) u8 {
    var zr: V = @splat(0);
    var zi: V = @splat(0);
    var tr: V = @splat(0);
    var ti: V = @splat(0);
    const four: V = @splat(4.0);
    for (0..10) |_| {
        inline for (0..5) |_| {
            zi = (zr + zr) * zi + ci;
            zr = tr - ti + cr;
            tr = zr * zr;
            ti = zi * zi;
        }
        if (!@reduce(.Or, tr + ti <= four)) return 0;
    }
    const bits: @Vector(8, u8) = .{ 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };
    return @reduce(.Or, @select(u8, tr + ti <= four, bits, @as(@Vector(8, u8), @splat(0))));
}

fn renderRow(img: *Image, y: usize) void {
    const wf: f64 = @floatFromInt(img.w);
    const ci: V = @splat(2.0 * @as(f64, @floatFromInt(y)) / wf - 1.0);
    const row = img.pixels[y * img.row_bytes ..][0..img.row_bytes];
    for (row, img.xs) |*b, cr| b.* = byteAt(cr, ci);
    // Pixels past the width in the last byte are zero bits, as the C program pads them.
    const extra = img.row_bytes * 8 - img.w;
    if (extra != 0) row[img.row_bytes - 1] &= @as(u8, 0xff) << @intCast(extra);
}

fn worker(img: *Image) void {
    const h = img.w;
    while (true) {
        const y = img.next_row.fetchAdd(1, .monotonic);
        if (y >= h) return;
        renderRow(img, y);
    }
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const w: usize = @intCast(atoi(argv[1]));
    const row_bytes = (w + 7) / 8;
    const pixels = std.heap.c_allocator.alloc(u8, row_bytes * w) catch unreachable;
    const xs = std.heap.c_allocator.alloc(V, row_bytes) catch unreachable;
    const wf: f64 = @floatFromInt(w);
    for (xs, 0..) |*v, k| {
        var a: [8]f64 = undefined;
        for (&a, 0..) |*e, l| e.* = 2.0 * @as(f64, @floatFromInt(k * 8 + l)) / wf - 1.5;
        v.* = a;
    }
    var img = Image{ .w = w, .row_bytes = row_bytes, .pixels = pixels, .xs = xs, .next_row = .init(0) };

    const nthreads = std.Thread.getCpuCount() catch 1;
    const threads = std.heap.c_allocator.alloc(std.Thread, nthreads - 1) catch unreachable;
    for (threads) |*t| t.* = std.Thread.spawn(.{}, worker, .{&img}) catch unreachable;
    worker(&img);
    for (threads) |*t| t.join();

    _ = printf("P4\n%d %d\n", @as(c_int, @intCast(w)), @as(c_int, @intCast(w)));
    _ = fflush(null);
    var off: usize = 0;
    while (off < pixels.len) {
        const r = write(1, pixels[off..].ptr, pixels.len - off);
        if (r <= 0) break;
        off += @intCast(r);
    }
    return 0;
}
