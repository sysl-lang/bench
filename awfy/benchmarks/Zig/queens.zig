//! queens.h. The four arrays are allocated and freed on each call of
//! `queens`, held in fields, as in C++.

const mem = @import("mem.zig");

pub const Queens = struct {
    free_maxs: []bool = &.{},
    free_rows: []bool = &.{},
    free_mins: []bool = &.{},
    queen_rows: []i32 = &.{},

    fn queens(self: *Queens) bool {
        self.free_rows = mem.alloc(bool, 8);
        @memset(self.free_rows, true);
        self.free_maxs = mem.alloc(bool, 16);
        @memset(self.free_maxs, true);
        self.free_mins = mem.alloc(bool, 16);
        @memset(self.free_mins, true);
        self.queen_rows = mem.alloc(i32, 8);
        @memset(self.queen_rows, -1);

        const result = self.placeQueen(0);

        mem.free(self.free_rows);
        mem.free(self.free_maxs);
        mem.free(self.free_mins);
        mem.free(self.queen_rows);

        return result;
    }

    fn placeQueen(self: *Queens, c: i32) bool {
        var r: i32 = 0;
        while (r < 8) : (r += 1) {
            if (self.getRowColumn(r, c)) {
                self.queen_rows[@intCast(r)] = c;
                self.setRowColumn(r, c, false);

                if (c == 7) return true;
                if (self.placeQueen(c + 1)) return true;
                self.setRowColumn(r, c, true);
            }
        }
        return false;
    }

    fn getRowColumn(self: *const Queens, r: i32, c: i32) bool {
        return self.free_rows[@intCast(r)] and self.free_maxs[@intCast(c + r)] and self.free_mins[@intCast(c - r + 7)];
    }

    fn setRowColumn(self: *Queens, r: i32, c: i32, v: bool) void {
        self.free_rows[@intCast(r)] = v;
        self.free_maxs[@intCast(c + r)] = v;
        self.free_mins[@intCast(c - r + 7)] = v;
    }

    pub fn benchmark(self: *Queens) bool {
        var result = true;
        var i: i32 = 0;
        while (i < 10) : (i += 1) result = result and self.queens();
        return result;
    }

    pub fn verifyResult(_: *Queens, result: bool) bool {
        return result;
    }
};
