// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Kevin Carson) to C3.
module binarytrees;
import std::io;

struct TreeNode
{
	TreeNode* left;
	TreeNode* right;
}

fn TreeNode* new_tree_node(TreeNode* left, TreeNode* right)
{
	TreeNode* node = mem::alloc(TreeNode);
	node.left = left;
	node.right = right;
	return node;
}

fn long item_check(TreeNode* tree)
{
	if (tree.left == null) return 1;
	return 1 + item_check(tree.left) + item_check(tree.right);
}

fn TreeNode* bottom_up_tree(uint depth)
{
	if (depth > 0) return new_tree_node(bottom_up_tree(depth - 1), bottom_up_tree(depth - 1));
	return new_tree_node(null, null);
}

fn void delete_tree(TreeNode* tree)
{
	if (tree.left != null)
	{
		delete_tree(tree.left);
		delete_tree(tree.right);
	}
	mem::free(tree);
}

fn int main(String[] args)
{
	uint n = args[1].to_uint()!!;
	uint min_depth = 4;
	uint max_depth = min_depth + 2 > n ? min_depth + 2 : n;
	uint stretch_depth = max_depth + 1;

	TreeNode* stretch_tree = bottom_up_tree(stretch_depth);
	io::printfn("stretch tree of depth %d\t check: %d", stretch_depth, item_check(stretch_tree));
	delete_tree(stretch_tree);

	TreeNode* long_lived_tree = bottom_up_tree(max_depth);

	for (uint depth = min_depth; depth <= max_depth; depth += 2)
	{
		long iterations = 1L << (max_depth - depth + min_depth);
		long check = 0;
		for (long i = 1; i <= iterations; i++)
		{
			TreeNode* temp_tree = bottom_up_tree(depth);
			check += item_check(temp_tree);
			delete_tree(temp_tree);
		}
		io::printfn("%d\t trees of depth %d\t check: %d", iterations, depth, check);
	}

	io::printfn("long lived tree of depth %d\t check: %d", max_depth, item_check(long_lived_tree));
	return 0;
}
