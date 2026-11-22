//! som/vector.h: the suite's growable array, with the C++ port's storage
//! policy (capacity doubles, `removeFirst` advances a start index, `removeAll`
//! reallocates at the same capacity).
//!
//! The C++ closures (`std::function`) become a context value plus a function
//! known at compile time, the standard library's own higher-order form
//! (`std.sort.insertion(T, items, context, lessThanFn)`).

const mem = @import("../mem.zig");

pub const initial_size = 10;

pub fn Vector(comptime E: type) type {
    return struct {
        const Self = @This();

        /// The C++ `E* storage` with its `_capacity`: empty is `nullptr`.
        storage: []E,
        first_idx: usize = 0,
        last_idx: usize = 0,

        pub fn init(initial_capacity: usize) Self {
            return .{ .storage = if (initial_capacity == 0) &.{} else mem.alloc(E, initial_capacity) };
        }

        pub fn deinit(self: *Self) void {
            if (self.storage.len != 0) mem.free(self.storage);
        }

        /// `Vector<E>::with`: a new heap Vector holding `elem`.
        pub fn with(elem: E) *Self {
            const v = mem.create(Self, init(1));
            v.append(elem);
            return v;
        }

        /// `delete v` for a heap Vector.
        pub fn destroy(self: *Self) void {
            self.deinit();
            mem.destroy(self);
        }

        /// `delete` of every element: E is a pointer to a type that may have a destructor.
        pub fn destroyValues(self: *Self) void {
            const T = @typeInfo(E).pointer.child;
            for (self.storage[self.first_idx..self.last_idx]) |v| {
                if (@hasDecl(T, "deinit")) v.deinit();
                mem.destroy(v);
            }
        }

        pub fn at(self: *const Self, idx: usize) ?*E {
            if (self.storage.len == 0 or idx >= self.last_idx - self.first_idx) return null;
            return &self.storage[self.first_idx + idx];
        }

        pub fn atPut(self: *Self, idx: usize, val: E) void {
            if (self.storage.len == 0) {
                self.storage = mem.alloc(E, @max(idx + 1, initial_size));
            } else if (idx >= self.last_idx - self.first_idx) {
                var new_length = self.storage.len;
                while (new_length <= idx + self.first_idx) new_length *= 2;
                const new_storage = mem.alloc(E, new_length);
                @memcpy(new_storage[0..self.last_idx], self.storage[0..self.last_idx]);
                mem.free(self.storage);
                self.storage = new_storage;
            }
            self.storage[self.first_idx + idx] = val;
            if (self.last_idx < idx + 1) self.last_idx = idx + 1;
        }

        pub fn append(self: *Self, elem: E) void {
            if (self.storage.len == 0) {
                self.storage = mem.alloc(E, initial_size);
            } else if (self.last_idx >= self.storage.len) {
                const new_storage = mem.alloc(E, self.storage.len * 2);
                @memcpy(new_storage[0..self.last_idx], self.storage[0..self.last_idx]);
                mem.free(self.storage);
                self.storage = new_storage;
            }
            self.storage[self.last_idx] = elem;
            self.last_idx += 1;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.last_idx == self.first_idx;
        }

        pub fn forEach(self: *const Self, context: anytype, comptime f: fn (@TypeOf(context), E) void) void {
            for (self.storage[self.first_idx..self.last_idx]) |e| f(context, e);
        }

        pub fn hasSome(self: *const Self, context: anytype, comptime f: fn (@TypeOf(context), E) bool) bool {
            for (self.storage[self.first_idx..self.last_idx]) |e| {
                if (f(context, e)) return true;
            }
            return false;
        }

        pub fn getOne(self: *const Self, context: anytype, comptime f: fn (@TypeOf(context), E) bool) ?E {
            for (self.storage[self.first_idx..self.last_idx]) |e| {
                if (f(context, e)) return e;
            }
            return null;
        }

        pub fn first(self: *const Self) ?E {
            if (self.isEmpty()) return null;
            return self.storage[self.first_idx];
        }

        pub fn removeFirst(self: *Self) ?E {
            if (self.isEmpty()) return null;
            self.first_idx += 1;
            return self.storage[self.first_idx - 1];
        }

        pub fn remove(self: *Self, obj: E) bool {
            if (self.storage.len == 0 or self.isEmpty()) return false;
            var found = false;
            var new_last = self.first_idx;
            for (self.first_idx..self.last_idx) |i| {
                if (self.storage[i] == obj) {
                    found = true;
                } else {
                    self.storage[new_last] = self.storage[i];
                    new_last += 1;
                }
            }
            self.last_idx = new_last;
            return found;
        }

        pub fn removeAll(self: *Self) void {
            self.destroyValues();
            self.first_idx = 0;
            self.last_idx = 0;
            if (self.storage.len != 0) {
                const capacity = self.storage.len;
                mem.free(self.storage);
                self.storage = mem.alloc(E, capacity);
            }
        }

        pub fn size(self: *const Self) usize {
            return self.last_idx - self.first_idx;
        }

        pub fn getCapacity(self: *const Self) usize {
            return self.storage.len;
        }

        /// `sort(c)`: the C++ port's quicksort, whose `swap` is not
        /// implemented and exits; the benchmarks only sort lists it never swaps.
        pub fn sort(self: *Self, context: anytype, comptime c: fn (@TypeOf(context), E, E) i32) void {
            if (self.size() > 0) self.sortRange(self.first_idx, self.last_idx - 1, context, c);
        }

        fn sortRange(self: *Self, i: usize, j: usize, context: anytype, comptime c: fn (@TypeOf(context), E, E) i32) void {
            const n = j + 1 - i;
            if (n <= 1) return;

            var di = self.storage[i];
            var dj = self.storage[j];

            if (c(context, di, dj) > 0) {
                swap();
                const tt = di;
                di = dj;
                dj = tt;
            }

            if (n > 2) {
                const ij = (i + j) / 2;
                var dij = self.storage[ij];

                if (c(context, di, dij) <= 0) {
                    if (c(context, dij, dj) > 0) {
                        swap();
                        dij = dj;
                    }
                } else {
                    swap();
                    dij = di;
                }

                if (n > 3) {
                    var k = i;
                    var l = j - 1;
                    while (true) {
                        while (k <= l and c(context, dij, self.storage[l]) <= 0) l -%= 1;
                        k += 1;
                        while (k <= l and c(context, self.storage[k], dij) <= 0) k += 1;
                        if (k > l) break;
                        swap();
                    }
                    self.sortRange(i, l, context, c);
                    self.sortRange(k, j, context, c);
                }
            }
        }

        fn swap() noreturn {
            @branchHint(.cold);
            @panic("swap not implemented");
        }
    };
}
