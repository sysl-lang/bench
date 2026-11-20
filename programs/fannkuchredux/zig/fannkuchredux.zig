// The Computer Language Benchmarks Game: fannkuch-redux. Original, written for this benchmark: every
// permutation in the order the Game fixes, flipping until a 1 leads. It mirrors the Game's fastest C
// program that builds here (fannkuchredux.gcc-5, Jeremy Zerfas): the n! permutations are cut into
// blocks of consecutive indices shared out between threads, and a flip keeps the first value out of
// the array and reverses only the elements between. Here the blocks are smaller (720 per core) and
// taken from an atomic counter, where gcc-5 hands twelve blocks to OpenMP's static schedule, so the
// slower efficiency cores do not leave the others waiting. A thread rebuilds the first permutation
// of its block from the block's index (in the factorial number system) and steps through the rest
// with the count array; a permutation's sign in the checksum is its index's parity. The per-thread
// checksums and maxima are added and compared at the end.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;

const MAX_N = 16;

var n: usize = 0;
var fact: [MAX_N + 1]usize = undefined;
var block_size: usize = 0;
var nblocks: usize = 0;
var next_block = std.atomic.Value(usize).init(0);
var total_checksum = std.atomic.Value(i64).init(0);
var total_max = std.atomic.Value(i64).init(0);

fn worker() void {
    var p: [MAX_N]u8 = undefined;
    var pp: [MAX_N]u8 = undefined;
    var count: [MAX_N]usize = undefined;
    var checksum: i64 = 0;
    var max_flips: i64 = 0;

    while (true) {
        const block = next_block.fetchAdd(1, .monotonic);
        if (block >= nblocks) break;
        const first = block * block_size;
        const last = @min(first + block_size, fact[n]);

        // The permutation whose index is `first`.
        for (0..n) |i| p[i] = @intCast(i);
        var idx = first;
        var i = n - 1;
        while (i > 0) : (i -= 1) {
            const d = idx / fact[i];
            count[i] = d;
            idx %= fact[i];
            @memcpy(pp[0 .. i + 1], p[0 .. i + 1]);
            for (0..i + 1) |j| p[j] = if (j + d <= i) pp[j + d] else pp[j + d - i - 1];
        }

        var index = first;
        while (true) {
            if (p[0] != 0) {
                @memcpy(pp[1..n], p[1..n]);
                // The first value is kept out of the array: each flip puts it at its own index
                // and reverses only the elements between.
                var flips: i64 = 1;
                var f: usize = p[0];
                while (pp[f] != 0) : (flips += 1) {
                    const new_f = pp[f];
                    pp[f] = @intCast(f);
                    if (f > 2) {
                        var lo: usize = 1;
                        var hi: usize = f - 1;
                        while (lo < hi) : ({
                            lo += 1;
                            hi -= 1;
                        }) {
                            const t = pp[lo];
                            pp[lo] = pp[hi];
                            pp[hi] = t;
                        }
                    }
                    f = new_f;
                }
                if (flips > max_flips) max_flips = flips;
                checksum += if (index % 2 == 0) flips else -flips;
            }
            index += 1;
            if (index >= last) break;

            // The next permutation in the count-array order.
            var head = p[1];
            p[1] = p[0];
            p[0] = head;
            var k: usize = 1;
            count[k] += 1;
            while (count[k] > k) {
                count[k] = 0;
                k += 1;
                const nxt = p[1];
                p[0] = nxt;
                for (1..k) |j| p[j] = p[j + 1];
                p[k] = head;
                head = nxt;
                count[k] += 1;
            }
        }
    }
    _ = total_checksum.fetchAdd(checksum, .monotonic);
    var cur = total_max.load(.monotonic);
    while (max_flips > cur) {
        cur = total_max.cmpxchgWeak(cur, max_flips, .monotonic, .monotonic) orelse break;
    }
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    if (argc < 2) return 1;
    const arg = atoi(argv[1]);
    if (arg < 3 or arg > 15) return 1;
    n = @intCast(arg);
    fact[0] = 1;
    for (1..n + 1) |i| fact[i] = fact[i - 1] * i;

    const nthreads = std.Thread.getCpuCount() catch 1;
    nblocks = @min(fact[n], 720 * nthreads);
    block_size = (fact[n] + nblocks - 1) / nblocks;
    nblocks = (fact[n] + block_size - 1) / block_size;

    const threads = std.heap.c_allocator.alloc(std.Thread, nthreads - 1) catch unreachable;
    for (threads) |*t| t.* = std.Thread.spawn(.{}, worker, .{}) catch unreachable;
    worker();
    for (threads) |*t| t.join();

    _ = printf("%d\nPfannkuchen(%d) = %d\n", @as(c_int, @intCast(total_checksum.load(.monotonic))), arg, @as(c_int, @intCast(total_max.load(.monotonic))));
    return 0;
}
