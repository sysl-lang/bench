// The Computer Language Benchmarks Game: fasta. Same algorithm as the C version
// (linear symbol lookup, LINELEN-wide lines). Output goes through a 64 KiB buffer that is
// written with write(2), standing in for the stdio buffering the C version uses.
const std = @import("std");

extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn write(fd: c_int, buf: [*]const u8, n: usize) isize;

const IM: u32 = 139968;
const IA: u32 = 3877;
const IC: u32 = 29573;
const LINELEN = 60;

var seed: u32 = 42;

inline fn fastaRand() f64 {
    seed = (seed * IA + IC) % IM;
    return 1.0 * @as(f64, @floatFromInt(seed)) / @as(f64, @floatFromInt(IM));
}

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
    if (olen + data.len > obuf.len) flush();
    @memcpy(obuf[olen..][0..data.len], data);
    olen += data.len;
}

fn putc(c: u8) void {
    if (olen == obuf.len) flush();
    obuf[olen] = c;
    olen += 1;
}

const alu =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" ++
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" ++
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" ++
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" ++
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" ++
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" ++
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

const iub = "acgtBDHKMNRSVWY";
const iub_p = [_]f64{ 0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02 };

const homosapiens = "acgt";
const homosapiens_p = [_]f64{ 0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008 };

fn repeatFasta(seq: []const u8, n: usize) void {
    const len = seq.len;
    var buffer: [len_max]u8 = undefined;
    @memcpy(buffer[0..len], seq);
    @memcpy(buffer[len..][0..LINELEN], seq[0..LINELEN]);

    var t: usize = 0;
    const whole_lines = n / LINELEN;
    var i: usize = 0;
    while (i < whole_lines) : (i += 1) {
        put(buffer[t % len ..][0..LINELEN]);
        putc('\n');
        t += LINELEN;
    }
    put(buffer[t % len ..][0 .. n - t]);
    if (n % LINELEN != 0) putc('\n');
}

const len_max = alu.len + LINELEN;

fn linearLookup(p: []const f64, v: f64) usize {
    var i: usize = 0;
    for (p[0 .. p.len - 1]) |pj| {
        if (v > pj) i += 1;
    }
    return i;
}

fn randomFasta(symb: []const u8, probability: []const f64, n: usize) void {
    var p: [16]f64 = undefined;
    const len = symb.len;
    var buffer: [LINELEN + 1]u8 = undefined;
    buffer[LINELEN] = '\n';

    p[0] = probability[0];
    for (1..len) |i| p[i] = probability[i] + p[i - 1];

    const lines = n / LINELEN;
    for (0..lines) |_| {
        for (0..LINELEN) |k| {
            const v = fastaRand();
            buffer[k] = symb[linearLookup(p[0..len], v)];
        }
        put(&buffer);
    }
    const remainder = n - lines * LINELEN;
    for (0..remainder) |k| {
        const v = fastaRand();
        buffer[k] = symb[linearLookup(p[0..len], v)];
    }
    put(buffer[0..remainder]);
    if (n % LINELEN != 0) putc('\n');
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    const n: usize = if (argc > 1) @intCast(atoi(argv[1])) else 1000;

    put(">ONE Homo sapiens alu\n");
    repeatFasta(alu, n * 2);

    put(">TWO IUB ambiguity codes\n");
    randomFasta(iub, &iub_p, n * 3);

    put(">THREE Homo sapiens frequency\n");
    randomFasta(homosapiens, &homosapiens_p, n * 5);

    flush();
    return 0;
}
