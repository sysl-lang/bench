// The Computer Language Benchmarks Game: k-nucleotide. Original, written for this benchmark after
// the Game's fastest C program (knucleotide.gcc, Jeremy Zerfas): one pass per oligonucleotide length
// over the encoded sequence, rolling the 2k-bit key one base at a time and counting it in a library
// hash table (Zig's std.HashMap, with gcc's hash `key ^ key >> 7` and khash's 77% load). The seven tables (two frequency tables,
// five counts) are built at once, one thread each, as the Game's fastest C program builds them in
// OpenMP sections; each writes its report into its own buffer, and the buffers are printed in order.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn snprintf(buf: [*]u8, size: usize, fmt: [*:0]const u8, ...) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, n: usize) isize;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn realloc(p: ?*anyopaque, n: usize) ?*anyopaque;

const alloc = std.heap.c_allocator;
// The C program's khash table: its hash `key ^ key >> 7`, and khash's 77% maximum load.
const KeyContext = struct {
    pub fn hash(_: KeyContext, key: u64) u64 {
        return key ^ (key >> 7);
    }
    pub fn eql(_: KeyContext, a: u64, b: u64) bool {
        return a == b;
    }
};
const Map = std.HashMap(u64, u32, KeyContext, 77);

// A=0, C=1, G=2, T=3, for either case.
inline fn codeForNucleotide(c: u8) u8 {
    return switch (c & 7) {
        1 => 0,
        3 => 1,
        7 => 2,
        4 => 3,
        else => 0,
    };
}

const Element = struct { key: u64, value: u32 };

fn elementLess(_: void, a: Element, b: Element) bool {
    if (a.value != b.value) return a.value > b.value;
    return a.key < b.key;
}

fn countAll(poly: []const u8, len: usize) Map {
    var map = Map.init(alloc);
    var key: u64 = 0;
    const mask: u64 = (@as(u64, 1) << @intCast(2 * len)) - 1;
    var i: usize = 0;
    while (i + 1 < len) : (i += 1) key = ((key << 2) & mask) | poly[i];
    while (i < poly.len) : (i += 1) {
        key = ((key << 2) & mask) | poly[i];
        const e = map.getOrPut(key) catch unreachable;
        if (e.found_existing) e.value_ptr.* += 1 else e.value_ptr.* = 1;
    }
    return map;
}

const Report = struct {
    buf: [1024]u8 = undefined,
    len: usize = 0,
};

fn frequencies(poly: []const u8, len: usize, r: *Report) void {
    var map = countAll(poly, len);
    defer map.deinit();

    const elements = alloc.alloc(Element, map.count()) catch unreachable;
    defer alloc.free(elements);
    var it = map.iterator();
    var n: usize = 0;
    while (it.next()) |e| : (n += 1) elements[n] = .{ .key = e.key_ptr.*, .value = e.value_ptr.* };

    std.mem.sort(Element, elements, {}, elementLess);

    const total: f32 = @floatFromInt(poly.len - len + 1);
    for (elements) |e| {
        var name: [32:0]u8 = undefined;
        var key = e.key;
        var j = len;
        while (j > 0) {
            j -= 1;
            name[j] = "ACGT"[key & 3];
            key >>= 2;
        }
        name[len] = 0;
        const pct: f32 = 100.0 * @as(f32, @floatFromInt(e.value)) / total;
        r.len += @intCast(snprintf(r.buf[r.len..].ptr, r.buf.len - r.len, "%s %.3f\n", @as([*:0]const u8, &name), @as(f64, pct)));
    }
    r.len += @intCast(snprintf(r.buf[r.len..].ptr, r.buf.len - r.len, "\n"));
}

fn count(poly: []const u8, oligo: []const u8, r: *Report) void {
    var map = countAll(poly, oligo.len);
    defer map.deinit();
    var key: u64 = 0;
    for (oligo) |c| key = (key << 2) | codeForNucleotide(c);
    const n: u64 = map.get(key) orelse 0;
    r.len += @intCast(snprintf(&r.buf, r.buf.len, "%llu\t%.*s\n", @as(c_ulonglong, n), @as(c_int, @intCast(oligo.len)), oligo.ptr));
}

pub export fn main() c_int {
    // Read the whole of standard input.
    var cap: usize = 1 << 20;
    var buf: [*]u8 = @ptrCast(malloc(cap).?);
    var len: usize = 0;
    while (true) {
        if (len == cap) {
            cap *= 2;
            buf = @ptrCast(realloc(buf, cap).?);
        }
        const r = read(0, buf + len, cap - len);
        if (r <= 0) break;
        len += @intCast(r);
    }
    const input = buf[0..len];

    // Find the start of the third polynucleotide.
    var pos: usize = 0;
    while (pos < input.len and !std.mem.startsWith(u8, input[pos..], ">THREE")) {
        pos = (std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len) + 1;
    }
    pos = (std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len) + 1;

    const poly = alloc.alloc(u8, input.len - @min(pos, input.len)) catch unreachable;
    var plen: usize = 0;
    while (pos < input.len and input[pos] != '>') {
        const end = std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len;
        for (input[pos..end]) |c| {
            poly[plen] = codeForNucleotide(c);
            plen += 1;
        }
        pos = end + 1;
    }
    const polynucleotide = poly[0..plen];

    var reports: [7]Report = @splat(.{});
    const oligos = [_][]const u8{ "GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT" };
    var threads: [7]std.Thread = undefined;
    // The longest first, as the C program orders its sections.
    var k: usize = oligos.len;
    while (k > 0) {
        k -= 1;
        threads[2 + k] = std.Thread.spawn(.{}, count, .{ polynucleotide, oligos[k], &reports[2 + k] }) catch unreachable;
    }
    threads[1] = std.Thread.spawn(.{}, frequencies, .{ polynucleotide, 2, &reports[1] }) catch unreachable;
    threads[0] = std.Thread.spawn(.{}, frequencies, .{ polynucleotide, 1, &reports[0] }) catch unreachable;
    for (&threads) |*t| t.join();
    for (&reports) |*r| {
        r.buf[r.len] = 0;
        _ = printf("%s", @as([*:0]const u8, @ptrCast(&r.buf)));
    }
    return 0;
}
