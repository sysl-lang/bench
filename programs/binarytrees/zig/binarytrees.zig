// The Computer Language Benchmarks Game: binary-trees. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (binarytrees.gcc-2, Jeremy Zerfas): every
// node is allocated separately from a library memory pool (APR's there; Zig's standard
// std.heap.ArenaAllocator here), a pool is cleared after each tree instead of freeing nodes one by
// one, and the work is threaded as gcc-2 threads it: one thread per depth builds and checks that
// depth's trees in its own pool while the main thread builds and checks the long-lived tree; the
// results are printed in depth order once every thread has joined.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atoi(s: [*:0]const u8) c_int;

const Node = struct {
    left: ?*Node = null,
    right: ?*Node = null,
};

fn createTree(depth: usize, a: std.mem.Allocator) *Node {
    const node = a.create(Node) catch unreachable;
    node.* = .{};
    if (depth > 0) {
        node.left = createTree(depth - 1, a);
        node.right = createTree(depth - 1, a);
    }
    return node;
}

fn check(node: *const Node) i64 {
    if (node.left) |l| return check(l) + check(node.right.?) + 1;
    return 1;
}

const MIN_DEPTH = 4;
var checks: [32]i64 = undefined;

fn depthWorker(depth: usize, max_depth: usize) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const iterations = @as(usize, 1) << @intCast(max_depth - depth + MIN_DEPTH);
    var total: i64 = 0;
    for (0..iterations) |_| {
        _ = arena.reset(.retain_capacity);
        total += check(createTree(depth, arena.allocator()));
    }
    checks[(depth - MIN_DEPTH) / 2] = total;
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const n: usize = @intCast(atoi(argv[1]));
    const max_depth: usize = @max(MIN_DEPTH + 2, n);

    var pool = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer pool.deinit();
    {
        const stretch_depth = max_depth + 1;
        const c = check(createTree(stretch_depth, pool.allocator()));
        _ = printf("stretch tree of depth %d\t check: %lld\n", @as(c_int, @intCast(stretch_depth)), @as(c_longlong, c));
        _ = pool.reset(.retain_capacity);
    }

    var threads: [32]std.Thread = undefined;
    var nthreads: usize = 0;
    var depth: usize = MIN_DEPTH;
    while (depth <= max_depth) : (depth += 2) {
        threads[nthreads] = std.Thread.spawn(.{}, depthWorker, .{ depth, max_depth }) catch unreachable;
        nthreads += 1;
    }

    const long_lived = createTree(max_depth, pool.allocator());
    const long_lived_check = check(long_lived);

    for (threads[0..nthreads]) |*t| t.join();

    depth = MIN_DEPTH;
    while (depth <= max_depth) : (depth += 2) {
        const iterations = @as(c_longlong, 1) << @intCast(max_depth - depth + MIN_DEPTH);
        _ = printf("%lld\t trees of depth %d\t check: %lld\n", iterations, @as(c_int, @intCast(depth)), @as(c_longlong, checks[(depth - MIN_DEPTH) / 2]));
    }
    _ = printf("long lived tree of depth %d\t check: %lld\n", @as(c_int, @intCast(max_depth)), @as(c_longlong, long_lived_check));
    return 0;
}
