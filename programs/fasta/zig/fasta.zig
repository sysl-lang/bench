// The Computer Language Benchmarks Game: fasta. Original, written for this benchmark. It mirrors the
// Game's fastest C program (fasta.gcc-3, Drake Diedrich), which is single-threaded: the symbol for
// each of the generator's IM states is looked up in a table built once from the cumulative
// probabilities (in single precision, as gcc-3 builds it), so the inner loop is one generator step
// and one load; whole buffers of 100 lines are filled with the newlines already in place and written
// with write(2); the repeated sequence is laid out once as len(alu) lines and written in whole copies.
const std = @import("std");

extern "c" fn atoi(s: [*:0]const u8) c_int;
extern "c" fn write(fd: c_int, buf: [*]const u8, n: usize) isize;

const IM: u32 = 139968;
const IA: u32 = 3877;
const IC: u32 = 29573;
const LINELEN = 60;
const BUFLINES = 100;

var seed: u32 = 42;

inline fn nextState() u32 {
    seed = (seed * IA + IC) % IM;
    return seed;
}

fn put(data: []const u8) void {
    var off: usize = 0;
    while (off < data.len) {
        const r = write(1, data[off..].ptr, data.len - off);
        if (r <= 0) return;
        off += @intCast(r);
    }
}

const alu =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" ++
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" ++
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" ++
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" ++
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" ++
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" ++
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

fn repeatFasta(seq: []const u8, n: usize) void {
    const len = seq.len;
    // len lines of LINELEN, each starting where the previous ended: one whole period of the output.
    var buf: [(LINELEN + 1) * alu.len]u8 = undefined;
    for (0..len) |i| {
        for (0..LINELEN) |k| buf[i * (LINELEN + 1) + k] = seq[(i * LINELEN + k) % len];
        buf[(i + 1) * (LINELEN + 1) - 1] = '\n';
    }
    const whole = n / (len * LINELEN);
    for (0..whole) |_| put(&buf);
    const remaining = n - whole * len * LINELEN;
    put(buf[0 .. remaining + remaining / LINELEN]);
    if (n % LINELEN != 0) put("\n");
}

fn buildTable(symb: []const u8, prob: []const f32) [IM]u8 {
    var table: [IM]u8 = undefined;
    var sum: f32 = prob[0];
    var j: usize = 0;
    var i: usize = 0;
    while (i < IM and j < symb.len) : (i += 1) {
        const r: f64 = 1.0 * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(IM));
        if (r >= sum) {
            j += 1;
            if (j < prob.len) sum += prob[j];
        }
        table[i] = symb[@min(j, symb.len - 1)];
    }
    return table;
}

var table_buf: [IM]u8 = undefined;
var line_buf: [(LINELEN + 1) * BUFLINES]u8 = undefined;

fn randomFasta(symb: []const u8, prob: []const f32, n: usize) void {
    table_buf = buildTable(symb, prob);
    const table = &table_buf;
    const buf = &line_buf;
    for (0..BUFLINES) |l| buf[l * (LINELEN + 1) + LINELEN] = '\n';

    const buffers = n / LINELEN / BUFLINES;
    for (0..buffers) |_| {
        for (0..BUFLINES) |l| {
            const line = buf[l * (LINELEN + 1) ..][0..LINELEN];
            for (line) |*c| c.* = table[nextState()];
        }
        put(buf);
    }
    const lines = n / LINELEN - buffers * BUFLINES;
    for (0..lines) |l| {
        const line = buf[l * (LINELEN + 1) ..][0..LINELEN];
        for (line) |*c| c.* = table[nextState()];
    }
    const partial = n - LINELEN * lines - buffers * BUFLINES * LINELEN;
    for (buf[lines * (LINELEN + 1) ..][0..partial]) |*c| c.* = table[nextState()];
    put(buf[0 .. lines * (LINELEN + 1) + partial]);
    if (n % LINELEN != 0) put("\n");
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    const n: usize = if (argc > 1) @intCast(atoi(argv[1])) else 1000;
    const iub_p = [_]f32{ 0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02 };
    const homosapiens_p = [_]f32{ 0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008 };

    put(">ONE Homo sapiens alu\n");
    repeatFasta(alu, n * 2);
    put(">TWO IUB ambiguity codes\n");
    randomFasta("acgtBDHKMNRSVWY", &iub_p, n * 3);
    put(">THREE Homo sapiens frequency\n");
    randomFasta("acgt", &homosapiens_p, n * 5);
    return 0;
}
