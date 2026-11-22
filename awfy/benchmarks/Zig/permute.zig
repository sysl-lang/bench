//! permute.h. The array is allocated and freed on each benchmark call, held
//! in a field, as in C++.

const mem = @import("mem.zig");

pub const Permute = struct {
    count: i32 = 0,
    v: []i32 = &.{},

    fn permute(self: *Permute, n: i32) void {
        self.count += 1;
        if (n != 0) {
            const n1 = n - 1;
            self.permute(n1);
            var i = n1;
            while (i >= 0) : (i -= 1) {
                self.swap(n1, i);
                self.permute(n1);
                self.swap(n1, i);
            }
        }
    }

    fn swap(self: *Permute, i: i32, j: i32) void {
        const ui: usize = @intCast(i);
        const uj: usize = @intCast(j);
        const tmp = self.v[ui];
        self.v[ui] = self.v[uj];
        self.v[uj] = tmp;
    }

    pub fn benchmark(self: *Permute) i32 {
        self.count = 0;
        self.v = mem.alloc(i32, 6);
        self.permute(6);
        mem.free(self.v);
        return self.count;
    }

    pub fn verifyResult(_: *Permute, result: i32) bool {
        return 8660 == result;
    }
};
