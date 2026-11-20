//! run.h: selects a benchmark by name, runs it `num_iterations` times, times
//! each run with a monotonic clock and prints upstream's harness lines.

const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;

const benchmarks = .{
    .{ "Bounce", @import("bounce.zig").Bounce },
    .{ "CD", @import("cd.zig").CD },
    .{ "Havlak", @import("havlak.zig").Havlak },
    .{ "Json", @import("json.zig").Json },
    .{ "List", @import("list.zig").List },
    .{ "Mandelbrot", @import("mandelbrot.zig").Mandelbrot },
    .{ "NBody", @import("nbody.zig").NBody },
    .{ "Permute", @import("permute.zig").Permute },
    .{ "Queens", @import("queens.zig").Queens },
    .{ "Richards", @import("richards.zig").Richards },
    .{ "Sieve", @import("sieve.zig").Sieve },
    .{ "Storage", @import("storage.zig").Storage },
    .{ "Towers", @import("towers.zig").Towers },
    .{ "DeltaBlue", @import("deltablue.zig").DeltaBlue },
};

const Suite = *const fn () Benchmark;

pub const Run = struct {
    name: []const u8,
    suite: Suite,
    num_iterations: i32 = 1,
    inner_iterations: i32 = 1,
    total: i64 = 0,
    out: *std.Io.Writer,
    io: std.Io,

    /// null when no benchmark has this name.
    pub fn init(name: []const u8, out: *std.Io.Writer, io: std.Io) ?Run {
        const suite = selectBenchmark(name) orelse return null;
        return .{ .name = name, .suite = suite, .out = out, .io = io };
    }

    pub fn runBenchmark(self: *Run) !void {
        try self.out.print("Starting {s} benchmark ...\n", .{self.name});
        const bench = self.suite();
        try self.doRuns(bench);
        bench.destroy();

        try self.reportBenchmark();
        try self.out.print("\n", .{});
    }

    pub fn printTotal(self: *const Run) !void {
        try self.out.print("Total Runtime: {d}us\n", .{self.total});
    }

    fn selectBenchmark(name: []const u8) ?Suite {
        inline for (benchmarks) |b| {
            if (std.mem.eql(u8, name, b[0])) return struct {
                fn create() Benchmark {
                    return Benchmark.create(b[1]);
                }
            }.create;
        }
        return null;
    }

    fn measure(self: *Run, bench: Benchmark) !void {
        const start_time = std.Io.Timestamp.now(self.io, .awake);
        if (!bench.innerBenchmarkLoop(self.inner_iterations)) {
            try self.out.print("Benchmark failed with incorrect result\n", .{});
            try self.out.flush();
            std.process.exit(1);
        }
        const end_time = std.Io.Timestamp.now(self.io, .awake);
        const run_time = start_time.durationTo(end_time).toMicroseconds();

        try self.printResult(run_time);
        self.total += run_time;
    }

    fn doRuns(self: *Run, bench: Benchmark) !void {
        var i: i32 = 0;
        while (i < self.num_iterations) : (i += 1) try self.measure(bench);
    }

    fn reportBenchmark(self: *const Run) !void {
        try self.out.print("{s}: iterations={d} average: {d}us total: {d}us\n", .{
            self.name, self.num_iterations, @divTrunc(self.total, self.num_iterations), self.total,
        });
    }

    fn printResult(self: *const Run, run_time: i64) !void {
        try self.out.print("{s}: iterations=1 runtime: {d}us\n", .{ self.name, run_time });
    }
};
