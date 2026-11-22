//! harness.cpp: `harness benchmark [num-iterations [inner-iter]]`.
//!
//! Debug builds also check that the run freed everything it allocated
//! (mem.zig) and exit 1 if not.

const std = @import("std");
const mem = @import("mem.zig");
const Run = @import("run.zig").Run;

fn printUsage(out: *std.Io.Writer) !void {
    try out.print("./harness benchmark [num-iterations [inner-iter]]\n", .{});
    try out.print("\n", .{});
    try out.print("  benchmark      - benchmark class name\n", .{});
    try out.print("  num-iterations - number of times to execute benchmark, default: 1\n", .{});
    try out.print("  inner-iter     - number of times the benchmark is executed in an inner loop,\n", .{});
    try out.print("                   which is measured in total, default: 1\n", .{});
}

pub fn main(init: std.process.Init) !u8 {
    const io = init.io;
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buffer);
    const out = &stdout.interface;

    var args = init.minimal.args.iterate();
    _ = args.skip();
    const name = args.next() orelse {
        try printUsage(out);
        try out.flush();
        return 1;
    };

    var run = Run.init(name, out, io) orelse {
        var err_buffer: [256]u8 = undefined;
        var stderr = std.Io.File.stderr().writer(io, &err_buffer);
        try stderr.interface.print("Benchmark not recognized: {s}\n", .{name});
        try stderr.interface.flush();
        return 1;
    };
    if (args.next()) |num_iterations| {
        run.num_iterations = try std.fmt.parseInt(i32, num_iterations, 10);
        if (args.next()) |inner_iterations| {
            run.inner_iterations = try std.fmt.parseInt(i32, inner_iterations, 10);
        }
    }

    try run.runBenchmark();
    try run.printTotal();
    try out.flush();

    if (!mem.noLeaks()) {
        std.debug.print("memory leaked\n", .{});
        return 1;
    }
    return 0;
}
