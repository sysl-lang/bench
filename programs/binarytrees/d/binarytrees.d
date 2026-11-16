// The Computer Language Benchmarks Game: binary-trees. A port of the C program (Kevin Carson's),
// written for this suite: every node is a separate malloc, built bottom-up, walked and freed.
import core.stdc.stdio : printf;
import core.stdc.stdlib : atol, malloc, free;

struct TreeNode
{
    TreeNode* left;
    TreeNode* right;
}

TreeNode* newTreeNode(TreeNode* left, TreeNode* right)
{
    auto node = cast(TreeNode*) malloc(TreeNode.sizeof);
    node.left = left;
    node.right = right;
    return node;
}

long itemCheck(TreeNode* tree)
{
    if (tree.left is null)
        return 1;
    return 1 + itemCheck(tree.left) + itemCheck(tree.right);
}

TreeNode* bottomUpTree(uint depth)
{
    if (depth > 0)
        return newTreeNode(bottomUpTree(depth - 1), bottomUpTree(depth - 1));
    return newTreeNode(null, null);
}

void deleteTree(TreeNode* tree)
{
    if (tree.left !is null)
    {
        deleteTree(tree.left);
        deleteTree(tree.right);
    }
    free(tree);
}

int main(string[] args)
{
    uint n = cast(uint) atol(args[1].ptr);
    enum uint minDepth = 4;
    uint maxDepth = (minDepth + 2) > n ? minDepth + 2 : n;
    uint stretchDepth = maxDepth + 1;

    auto stretchTree = bottomUpTree(stretchDepth);
    printf("stretch tree of depth %u\t check: %li\n", stretchDepth, itemCheck(stretchTree));
    deleteTree(stretchTree);

    auto longLivedTree = bottomUpTree(maxDepth);

    for (uint depth = minDepth; depth <= maxDepth; depth += 2)
    {
        long iterations = 1L << (maxDepth - depth + minDepth);
        long check = 0;
        foreach (_; 0 .. iterations)
        {
            auto tempTree = bottomUpTree(depth);
            check += itemCheck(tempTree);
            deleteTree(tempTree);
        }
        printf("%li\t trees of depth %u\t check: %li\n", iterations, depth, check);
    }

    printf("long lived tree of depth %u\t check: %li\n", maxDepth, itemCheck(longLivedTree));
    return 0;
}
