// The Computer Language Benchmarks Game: binary-trees. A port of the C program (Kevin Carson's),
// written for this suite: every node is a separate heap allocation, built bottom-up, walked and freed.
package main

import "core:fmt"
import "core:os"
import "core:strconv"

Tree_Node :: struct {
	left, right: ^Tree_Node,
}

new_tree_node :: proc(left, right: ^Tree_Node) -> ^Tree_Node {
	node := new(Tree_Node)
	node.left = left
	node.right = right
	return node
}

item_check :: proc(tree: ^Tree_Node) -> int {
	if tree.left == nil {
		return 1
	}
	return 1 + item_check(tree.left) + item_check(tree.right)
}

bottom_up_tree :: proc(depth: uint) -> ^Tree_Node {
	if depth > 0 {
		return new_tree_node(bottom_up_tree(depth - 1), bottom_up_tree(depth - 1))
	}
	return new_tree_node(nil, nil)
}

delete_tree :: proc(tree: ^Tree_Node) {
	if tree.left != nil {
		delete_tree(tree.left)
		delete_tree(tree.right)
	}
	free(tree)
}

main :: proc() {
	n_int, _ := strconv.parse_int(os.args[1])
	n := uint(n_int)
	MIN_DEPTH :: uint(4)
	max_depth := MIN_DEPTH + 2 if MIN_DEPTH + 2 > n else n
	stretch_depth := max_depth + 1

	stretch_tree := bottom_up_tree(stretch_depth)
	fmt.printf("stretch tree of depth %d\t check: %d\n", stretch_depth, item_check(stretch_tree))
	delete_tree(stretch_tree)

	long_lived_tree := bottom_up_tree(max_depth)

	for depth := MIN_DEPTH; depth <= max_depth; depth += 2 {
		iterations := 1 << (max_depth - depth + MIN_DEPTH)
		check := 0
		for _ in 0 ..< iterations {
			temp_tree := bottom_up_tree(depth)
			check += item_check(temp_tree)
			delete_tree(temp_tree)
		}
		fmt.printf("%d\t trees of depth %d\t check: %d\n", iterations, depth, check)
	}

	fmt.printf("long lived tree of depth %d\t check: %d\n", max_depth, item_check(long_lived_tree))
}
