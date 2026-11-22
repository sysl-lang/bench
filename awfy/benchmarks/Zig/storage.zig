//! storage.h. The tree is freed from its root: freeing an array first frees
//! each element's children (the C++ ArrayTree destructor).

const mem = @import("mem.zig");
const Random = @import("som/random.zig").Random;

const ArrayTree = struct {
    children: ?[]ArrayTree = null,

    /// `new ArrayTree[n]`.
    fn newArray(n: usize) []ArrayTree {
        const arr = mem.alloc(ArrayTree, n);
        @memset(arr, .{});
        return arr;
    }

    /// `delete[] arr`.
    fn deleteArray(arr: []ArrayTree) void {
        for (arr) |tree| {
            if (tree.children) |children| deleteArray(children);
        }
        mem.free(arr);
    }
};

pub const Storage = struct {
    count: i32 = 0,

    pub fn benchmark(self: *Storage) i32 {
        var random: Random = .{};

        self.count = 0;
        const result = self.buildTreeDepth(7, &random);
        ArrayTree.deleteArray(result);

        return self.count;
    }

    pub fn verifyResult(_: *Storage, result: i32) bool {
        return 5461 == result;
    }

    fn buildTreeDepth(self: *Storage, depth: i32, random: *Random) []ArrayTree {
        self.count += 1;
        if (depth == 1) {
            return ArrayTree.newArray(@intCast(@rem(random.next(), 10) + 1));
        }

        const arr = ArrayTree.newArray(4);
        for (arr) |*tree| tree.children = self.buildTreeDepth(depth - 1, random);
        return arr;
    }
};
