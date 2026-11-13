// The Computer Language Benchmarks Game: reverse-complement. Same algorithm as the C version:
// each sequence line is complemented through a 256-entry table (characters without an entry are
// dropped) and stored reversed, then the record is written in 60-column lines.
const std = @import("std");

extern "c" fn read(fd: c_int, buf: [*]u8, n: usize) isize;
extern "c" fn write(fd: c_int, buf: [*]const u8, n: usize) isize;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn realloc(p: ?*anyopaque, n: usize) ?*anyopaque;

var obuf: [1 << 16]u8 = undefined;
var olen: usize = 0;

fn flush() void {
    var off: usize = 0;
    while (off < olen) {
        const r = write(1, obuf[off..].ptr, olen - off);
        if (r <= 0) break;
        off += @intCast(r);
    }
    olen = 0;
}

fn put(data: []const u8) void {
    if (data.len > obuf.len) {
        flush();
        var off: usize = 0;
        while (off < data.len) {
            const r = write(1, data[off..].ptr, data.len - off);
            if (r <= 0) break;
            off += @intCast(r);
        }
        return;
    }
    if (olen + data.len > obuf.len) flush();
    @memcpy(obuf[olen..][0..data.len], data);
    olen += data.len;
}

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

// Writes the record's reversed complement, 60 bytes per line.
fn emit(rec: []const u8) void {
    var end = rec.len;
    var line: [61]u8 = undefined;
    while (end > 0) {
        const x = @min(end, 60);
        for (0..x) |k| line[k] = rec[end - 1 - k];
        line[x] = '\n';
        put(line[0 .. x + 1]);
        end -= x;
    }
}

pub export fn main() c_int {
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

    const rec: [*]u8 = @ptrCast(malloc(len + 1).?);
    var rlen: usize = 0;
    var pos: usize = 0;
    while (pos < input.len) {
        const end = std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len;
        const ln = input[pos..end];
        if (ln.len > 0 and ln[0] == '>') {
            emit(rec[0..rlen]);
            rlen = 0;
            put(ln);
            put("\n");
        } else {
            for (ln) |ch| {
                const c = xtab[ch];
                if (c != 0) {
                    rec[rlen] = c;
                    rlen += 1;
                }
            }
        }
        pos = end + 1;
    }
    emit(rec[0..rlen]);
    flush();
    return 0;
}
