// The Computer Language Benchmarks Game: binary-trees. Same algorithm as the C version:
// every node is its own malloc, and every tree is freed node by node.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn atol(s: [*:0]const u8) c_long;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn free(p: ?*anyopaque) void;

const TreeNode = struct {
    left: ?*TreeNode,
    right: ?*TreeNode,
};

fn newTreeNode(left: ?*TreeNode, right: ?*TreeNode) *TreeNode {
    const node: *TreeNode = @ptrCast(@alignCast(malloc(@sizeOf(TreeNode)).?));
    node.left = left;
    node.right = right;
    return node;
}

fn itemCheck(tree: *TreeNode) c_long {
    if (tree.left == null) return 1;
    return 1 + itemCheck(tree.left.?) + itemCheck(tree.right.?);
}

fn bottomUpTree(depth: c_uint) *TreeNode {
    if (depth > 0) {
        const l = bottomUpTree(depth - 1);
        const r = bottomUpTree(depth - 1);
        return newTreeNode(l, r);
    }
    return newTreeNode(null, null);
}

fn deleteTree(tree: *TreeNode) void {
    if (tree.left != null) {
        deleteTree(tree.left.?);
        deleteTree(tree.right.?);
    }
    free(tree);
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    _ = argc;
    const n: c_uint = @intCast(atol(argv[1]));
    const minDepth: c_uint = 4;
    const maxDepth: c_uint = if (minDepth + 2 > n) minDepth + 2 else n;
    const stretchDepth = maxDepth + 1;

    const stretchTree = bottomUpTree(stretchDepth);
    _ = printf("stretch tree of depth %u\t check: %li\n", stretchDepth, itemCheck(stretchTree));
    deleteTree(stretchTree);

    const longLivedTree = bottomUpTree(maxDepth);

    var depth = minDepth;
    while (depth <= maxDepth) : (depth += 2) {
        const iterations: c_long = @as(c_long, 1) << @intCast(maxDepth - depth + minDepth);
        var check: c_long = 0;
        var i: c_long = 1;
        while (i <= iterations) : (i += 1) {
            const tempTree = bottomUpTree(depth);
            check += itemCheck(tempTree);
            deleteTree(tempTree);
        }
        _ = printf("%li\t trees of depth %u\t check: %li\n", iterations, depth, check);
    }

    _ = printf("long lived tree of depth %u\t check: %li\n", maxDepth, itemCheck(longLivedTree));
    return 0;
}
