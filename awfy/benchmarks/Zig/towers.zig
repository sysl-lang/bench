//! towers.h. The disks form linked lists, through which they are freed.

const std = @import("std");
const mem = @import("mem.zig");

const TowersDisk = struct {
    size: i32,
    next: ?*TowersDisk = null,

    /// `delete disk`, with the destructor's recursive `delete next`.
    fn destroy(self: *TowersDisk) void {
        if (self.next) |next| next.destroy();
        mem.destroy(self);
    }
};

fn fail(msg: []const u8) noreturn {
    @branchHint(.cold);
    std.debug.print("{s}", .{msg});
    std.process.exit(1);
}

pub const Towers = struct {
    piles: [3]?*TowersDisk = @splat(null),
    moves_done: i32 = 0,

    pub fn benchmark(self: *Towers) i32 {
        self.piles = @splat(null);
        self.buildTowerAt(0, 13);
        self.moves_done = 0;
        self.moveDisks(13, 0, 1);

        for (self.piles) |pile| {
            if (pile) |disk| disk.destroy();
        }
        return self.moves_done;
    }

    pub fn verifyResult(_: *Towers, result: i32) bool {
        return 8191 == result;
    }

    fn pushDisk(self: *Towers, disk: *TowersDisk, pile: usize) void {
        const top = self.piles[pile];
        if (top) |t| {
            if (disk.size >= t.size) fail("Cannot put a big disk on a smaller one");
        }
        disk.next = top;
        self.piles[pile] = disk;
    }

    fn popDiskFrom(self: *Towers, pile: usize) *TowersDisk {
        const top = self.piles[pile] orelse fail("Attempting to remove a disk from an empty pile");
        self.piles[pile] = top.next;
        top.next = null;
        return top;
    }

    fn moveTopDisk(self: *Towers, from_pile: usize, to_pile: usize) void {
        self.pushDisk(self.popDiskFrom(from_pile), to_pile);
        self.moves_done += 1;
    }

    fn buildTowerAt(self: *Towers, pile: usize, disks: i32) void {
        var i = disks;
        while (i >= 0) : (i -= 1) self.pushDisk(mem.create(TowersDisk, .{ .size = i }), pile);
    }

    fn moveDisks(self: *Towers, disks: i32, from_pile: usize, to_pile: usize) void {
        if (disks == 1) {
            self.moveTopDisk(from_pile, to_pile);
        } else {
            const other_pile = (3 - from_pile) - to_pile;
            self.moveDisks(disks - 1, from_pile, other_pile);
            self.moveTopDisk(from_pile, to_pile);
            self.moveDisks(disks - 1, other_pile, to_pile);
        }
    }
};
