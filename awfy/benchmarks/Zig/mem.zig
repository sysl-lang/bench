//! The port's heap: one general-purpose allocator used the way C++'s global
//! new/delete is used, and the C++ port's memory/object_tracker.
//!
//! Release builds use the allocator Zig's own start code hands `main` as
//! `std.process.Init.gpa`: libc's malloc when libc is linked (always on macOS,
//! where libSystem is the system interface), otherwise `smp_allocator`. Debug
//! builds use `DebugAllocator`, and the harness fails a run that leaks, which
//! proves every allocation is freed as the C++ port frees it.
//!
//! An allocation failure ends the process, as an uncaught std::bad_alloc does
//! in the C++ port; nothing in the suite recovers from one.

const std = @import("std");
const builtin = @import("builtin");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub const gpa: std.mem.Allocator = if (builtin.mode == .debug)
    debug_allocator.allocator()
else if (builtin.link_libc)
    std.heap.c_allocator
else
    std.heap.smp_allocator;

/// Debug builds: true when nothing allocated is still live.
pub fn noLeaks() bool {
    if (builtin.mode != .debug) return true;
    ObjectTracker.deinit();
    return debug_allocator.deinit() == .ok;
}

fn outOfMemory() noreturn {
    @branchHint(.cold);
    @panic("out of memory");
}

/// `new T(...)`.
pub fn create(comptime T: type, value: T) *T {
    const p = gpa.create(T) catch outOfMemory();
    p.* = value;
    return p;
}

/// `delete p`.
pub fn destroy(p: anytype) void {
    gpa.destroy(p);
}

/// `new T[n]`: uninitialized, as `new T[n]` is for the trivial types it is used with.
pub fn alloc(comptime T: type, n: usize) []T {
    return gpa.alloc(T, n) catch outOfMemory();
}

/// `delete[] s`.
pub fn free(s: anytype) void {
    gpa.free(s);
}

/// memory/object_tracker.h: objects of a graph with cycles are recorded as
/// they are created and all deleted at once by `releaseAll`. Each record
/// carries the object's destructor, as the C++ TrackedObject's virtual
/// destructor does.
pub const ObjectTracker = struct {
    const Tracked = struct {
        ptr: *anyopaque,
        destroy: *const fn (*anyopaque) void,
    };

    var tracked: std.ArrayList(Tracked) = .empty;

    pub fn track(comptime T: type, obj: *T) void {
        tracked.append(gpa, .{ .ptr = obj, .destroy = destructor(T) }) catch outOfMemory();
    }

    /// `new T(...)` for a TrackedObject subclass.
    pub fn new(comptime T: type, value: T) *T {
        const p = create(T, value);
        track(T, p);
        return p;
    }

    pub fn releaseAll() void {
        for (tracked.items) |t| t.destroy(t.ptr);
        tracked.clearRetainingCapacity();
    }

    fn deinit() void {
        tracked.deinit(gpa);
        tracked = .empty;
    }

    fn destructor(comptime T: type) *const fn (*anyopaque) void {
        return struct {
            fn run(p: *anyopaque) void {
                const obj: *T = @ptrCast(@alignCast(p));
                if (@hasDecl(T, "deinit")) obj.deinit();
                gpa.destroy(obj);
            }
        }.run;
    }
};
