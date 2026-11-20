// The Computer Language Benchmarks Game: binary-trees. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (binarytrees.gcc-2, Jeremy Zerfas): every node
// is allocated separately from a library memory pool (APR's there; C3's standard ArenaAllocator here,
// over one block sized for the deepest tree it will hold), a pool is cleared after each tree instead
// of freeing nodes one by one, and the work is threaded as gcc-2 threads it: one thread per depth
// builds and checks that depth's trees in its own pool while the main thread builds and checks the
// long-lived tree; the results are printed in depth order once every thread has joined.
module binarytrees;
import std::io;
import std::thread;
import std::core::mem::allocators;

struct TreeNode
{
	TreeNode* left;
	TreeNode* right;
}

// Bytes an arena needs for a tree of the given depth: each node with the arena's size header,
// aligned to 16.
fn sz pool_bytes(long depth) => (sz)((2L << depth) * 32 + 64);

fn TreeNode* create_tree(long depth, ArenaAllocator* pool)
{
	TreeNode* node = pool.acquire(TreeNode::size, NO_ZERO, 0)!!;
	if (depth > 0)
	{
		node.left = create_tree(depth - 1, pool);
		node.right = create_tree(depth - 1, pool);
	}
	else
	{
		node.left = null;
		node.right = null;
	}
	return node;
}

fn long check(TreeNode* node)
{
	if (node.left) return check(node.left) + check(node.right) + 1;
	return 1;
}

const long MIN_DEPTH = 4;
long max_depth;
long[32] checks;

fn int depth_worker(void* arg)
{
	long depth = (long)(iptr)arg;
	char[] block = mem::new_array(char, pool_bytes(depth));
	ArenaAllocator pool;
	pool.init(block);
	long iterations = 1L << (max_depth - depth + MIN_DEPTH);
	long total = 0;
	for (long i = 0; i < iterations; i++)
	{
		pool.clear();
		total += check(create_tree(depth, &pool));
	}
	checks[(depth - MIN_DEPTH) / 2] = total;
	mem::free(block);
	return 0;
}

fn int main(String[] args)
{
	long n = args[1].to_long()!!;
	max_depth = MIN_DEPTH + 2 > n ? MIN_DEPTH + 2 : n;

	char[] block = mem::new_array(char, pool_bytes(max_depth + 1));
	ArenaAllocator pool;
	pool.init(block);
	long stretch_depth = max_depth + 1;
	io::printfn("stretch tree of depth %d\t check: %d", stretch_depth, check(create_tree(stretch_depth, &pool)));
	pool.clear();

	Thread[32] threads;
	int nthreads = 0;
	for (long depth = MIN_DEPTH; depth <= max_depth; depth += 2)
	{
		threads[nthreads].create(&depth_worker, (void*)(iptr)depth)!!;
		nthreads++;
	}

	long long_lived_check = check(create_tree(max_depth, &pool));

	for (int i = 0; i < nthreads; i++) (void)threads[i].join();

	for (long depth = MIN_DEPTH; depth <= max_depth; depth += 2)
	{
		io::printfn("%d\t trees of depth %d\t check: %d", 1L << (max_depth - depth + MIN_DEPTH), depth, checks[(depth - MIN_DEPTH) / 2]);
	}
	io::printfn("long lived tree of depth %d\t check: %d", max_depth, long_lived_check);
	return 0;
}
