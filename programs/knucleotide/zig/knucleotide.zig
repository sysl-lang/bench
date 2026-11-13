// The Computer Language Benchmarks Game: k-nucleotide. Same algorithm as the C version:
// one pass per oligonucleotide length over the encoded sequence, counting 2-bit keys in a hash
// map (here the standard library's AutoHashMap), run sequentially.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, n: usize) isize;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn realloc(p: ?*anyopaque, n: usize) ?*anyopaque;

const alloc = std.heap.c_allocator;
const Map = std.AutoHashMap(u64, u32);

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

fn frequencies(poly: []const u8, len: usize) void {
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
        _ = printf("%s %.3f\n", @as([*:0]const u8, &name), @as(f64, pct));
    }
    _ = printf("\n");
}

fn count(poly: []const u8, oligo: []const u8) void {
    var map = countAll(poly, oligo.len);
    defer map.deinit();
    var key: u64 = 0;
    for (oligo) |c| key = (key << 2) | codeForNucleotide(c);
    const n: u64 = map.get(key) orelse 0;
    _ = printf("%llu\t%.*s\n", @as(c_ulonglong, n), @as(c_int, @intCast(oligo.len)), oligo.ptr);
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

    frequencies(polynucleotide, 1);
    frequencies(polynucleotide, 2);
    count(polynucleotide, "GGT");
    count(polynucleotide, "GGTA");
    count(polynucleotide, "GGTATT");
    count(polynucleotide, "GGTATTTTAATT");
    count(polynucleotide, "GGTATTTTAATTTATAGT");
    return 0;
}
