//! benchmark.h: the abstract Benchmark class, as the standard library's
//! interface pattern (a type-erased pointer plus a table of functions).
//!
//! A benchmark type provides either `innerBenchmarkLoop`, overriding the
//! default, or `benchmark` and `verifyResult`, which the default loop calls:
//! `verify_result(benchmark())` once per inner iteration, stopping at the
//! first wrong result. C++ returns `benchmark()`'s result as a `std::any`; here
//! it is the benchmark's own result type.

const mem = @import("mem.zig");

pub const Benchmark = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        innerBenchmarkLoop: *const fn (*anyopaque, i32) bool,
        destroy: *const fn (*anyopaque) void,
    };

    pub fn innerBenchmarkLoop(self: Benchmark, inner_iterations: i32) bool {
        return self.vtable.innerBenchmarkLoop(self.ptr, inner_iterations);
    }

    pub fn destroy(self: Benchmark) void {
        self.vtable.destroy(self.ptr);
    }

    /// `new T()` as a Benchmark.
    pub fn create(comptime T: type) Benchmark {
        return .{ .ptr = mem.create(T, .{}), .vtable = &Impl(T).vtable };
    }

    fn Impl(comptime T: type) type {
        return struct {
            const vtable: VTable = .{ .innerBenchmarkLoop = innerLoop, .destroy = destroyIt };

            fn innerLoop(p: *anyopaque, inner_iterations: i32) bool {
                const self: *T = @ptrCast(@alignCast(p));
                if (@hasDecl(T, "innerBenchmarkLoop")) {
                    return self.innerBenchmarkLoop(inner_iterations);
                } else {
                    var i: i32 = 0;
                    while (i < inner_iterations) : (i += 1) {
                        if (!self.verifyResult(self.benchmark())) return false;
                    }
                    return true;
                }
            }

            fn destroyIt(p: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(p));
                mem.destroy(self);
            }
        };
    }
};
