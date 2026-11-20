// The Computer Language Benchmarks Game: reverse-complement. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (revcomp.gcc-9, Jeremy Zerfas): the input is
// read whole; each record's output (its reverse complement in 60-column lines) is cut into chunks of
// lines that one thread per core fills; characters are complemented two at a time through a
// 65,536-entry table of byte pairs (gcc-9's idea, from roman blog's C++ program); and when a record
// is made of full 60-character lines (every fasta file is, but for its last line), the sequence is
// read straight from the input with no pass to remove the newlines, as gcc-9's fast path does. Any
// other record is first copied without its newlines. The whole output is written in one call.
const std = @import("std");

extern "c" fn read(fd: c_int, buf: [*]u8, n: usize) isize;
extern "c" fn write(fd: c_int, buf: [*]const u8, n: usize) isize;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn realloc(p: ?*anyopaque, n: usize) ?*anyopaque;

const LINE = 60;

fn makeTable() [256]u8 {
    var table: [256]u8 = @splat(0);
    const from = "ABCDGHKMNRSTVWY";
    const to = "TVGHCDMKNYSABWR";
    for (from, to) |f, t| {
        table[f] = t;
        table[f + 32] = t;
    }
    return table;
}

const xtab = makeTable();
// pair[b0 | b1 << 8] is the complement of the two bytes b0 b1 reversed: comp(b1) | comp(b0) << 8.
var pair: [65536]u16 = undefined;

// dst gets src's reverse complement.
inline fn revComp(dst: [*]u8, src: []const u8) void {
    var i: usize = 0;
    var e = src.len;
    while (e >= 2) : ({
        e -= 2;
        i += 2;
    }) {
        const v = std.mem.readInt(u16, src[e - 2 ..][0..2], .little);
        std.mem.writeInt(u16, dst[i..][0..2], pair[v], .little);
    }
    if (e == 1) dst[i] = xtab[src[0]];
}

// A record's sequence: either `seq` holds raw input in full 61-byte lines (`raw`), or it holds the
// sequence with its newlines removed and still to be complemented.
const Record = struct {
    seq: []const u8,
    len: usize, // characters, without newlines
    raw: bool,

    // The sequence characters [a, b) as at most two contiguous slices of `seq`.
    fn segments(r: Record, a: usize, b: usize, segs: *[2][]const u8) usize {
        if (!r.raw) {
            segs[0] = r.seq[a..b];
            return 1;
        }
        const la = a / LINE;
        const lb = (b - 1) / LINE;
        const pa = a + la;
        if (la == lb) {
            segs[0] = r.seq[pa .. b + lb];
            return 1;
        }
        segs[0] = r.seq[pa .. (la + 1) * (LINE + 1) - 1];
        segs[1] = r.seq[(la + 1) * (LINE + 1) .. b + lb];
        return 2;
    }
};

// Output lines [first, last) of the record into dst (each LINE characters and a newline, the last
// line shorter).
fn fillLines(r: Record, dst: [*]u8, first: usize, last: usize) void {
    var segs: [2][]const u8 = undefined;
    for (first..last) |l| {
        const end = r.len - l * LINE;
        const x = @min(end, LINE);
        var o = dst + l * (LINE + 1);
        const nseg = r.segments(end - x, end, &segs);
        // The later segment's characters come first in the reversed output.
        var k = nseg;
        while (k > 0) {
            k -= 1;
            revComp(o, segs[k]);
            o += segs[k].len;
        }
        o[0] = '\n';
    }
}

var nthreads: usize = 1;
var threads: [256]std.Thread = undefined;
var out: [*]u8 = undefined;
var olen: usize = 0;

fn emit(r: Record) void {
    const nlines = (r.len + LINE - 1) / LINE;
    const dst = out + olen;
    const per = @max(64, (nlines + nthreads - 1) / nthreads);
    var spawned: usize = 0;
    var first: usize = per;
    while (first < nlines) : (first += per) {
        threads[spawned] = std.Thread.spawn(.{}, fillLines, .{ r, dst, first, @min(first + per, nlines) }) catch unreachable;
        spawned += 1;
    }
    fillLines(r, dst, 0, @min(per, nlines));
    for (threads[0..spawned]) |*th| th.join();
    olen += r.len + nlines;
}

fn put(data: []const u8) void {
    @memcpy(out[olen..][0..data.len], data);
    olen += data.len;
}

// The record whose sequence lines are body (each ending in a newline but perhaps the last).
fn record(body: []const u8, scratch: [*]u8) Record {
    var n = body.len;
    if (n > 0 and body[n - 1] == '\n') n -= 1;
    const lines = n / (LINE + 1) + 1;
    var full = true;
    var k: usize = LINE;
    while (k < n) : (k += LINE + 1) {
        if (body[k] != '\n') {
            full = false;
            break;
        }
    }
    if (full and n > 0 and std.mem.indexOfScalar(u8, body[(lines - 1) * (LINE + 1) .. n], '\n') == null) {
        return .{ .seq = body[0..n], .len = n - (lines - 1), .raw = true };
    }
    var m: usize = 0;
    for (body) |c| {
        if (c != '\n') {
            scratch[m] = c;
            m += 1;
        }
    }
    return .{ .seq = scratch[0..m], .len = m, .raw = false };
}

pub export fn main() c_int {
    for (0..65536) |v| {
        const b0: u8 = @truncate(v);
        const b1: u8 = @truncate(v >> 8);
        pair[v] = @as(u16, xtab[b1]) | @as(u16, xtab[b0]) << 8;
    }
    nthreads = @min(threads.len, std.Thread.getCpuCount() catch 1);

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
    // The output is no longer than the input plus a newline per line and a final one.
    out = @ptrCast(malloc(len + len / LINE + 2).?);
    var scratch: ?[*]u8 = null;

    var pos: usize = 0;
    while (pos < input.len) {
        // A header line, then the sequence up to the next '>' at a line start.
        const hend = (std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len - 1) + 1;
        put(input[pos..hend]);
        var bend = hend;
        while (bend < input.len) {
            const nl = std.mem.indexOfScalarPos(u8, input, bend, '>') orelse input.len;
            bend = nl;
            if (nl == input.len or input[nl - 1] == '\n') break;
            bend += 1;
        }
        if (scratch == null) scratch = @ptrCast(malloc(len).?);
        const rec = record(input[hend..bend], scratch.?);
        if (rec.len > 0) emit(rec);
        pos = bend;
    }

    var off: usize = 0;
    while (off < olen) {
        const r = write(1, out + off, olen - off);
        if (r <= 0) break;
        off += @intCast(r);
    }
    return 0;
}
