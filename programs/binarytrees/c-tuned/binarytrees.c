/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   contributed by Kevin Carson

   *reset*

   Tuned for this suite: a short-lived tree is checked and freed in one walk
   (each node is counted, then its children are walked, then it is freed),
   where the plain program walks it twice; the long-lived and stretch trees
   likewise. Every node is still its own malloc and its own free.
*/

#include <stdio.h>
#include <stdlib.h>

typedef struct tn {
    struct tn*    left;
    struct tn*    right;
} treeNode;

static treeNode* BottomUpTree(unsigned depth)
{
    treeNode* new = malloc(sizeof(treeNode));
    if (depth > 0) {
        new->left = BottomUpTree(depth - 1);
        new->right = BottomUpTree(depth - 1);
    } else {
        new->left = new->right = NULL;
    }
    return new;
}

/* Counts the nodes of the tree and frees each one. */
static long CheckAndDelete(treeNode* tree)
{
    treeNode *l = tree->left, *r = tree->right;
    free(tree);
    if (l == NULL) return 1;
    return 1 + CheckAndDelete(l) + CheckAndDelete(r);
}

int main(int argc, char* argv[])
{
    unsigned N = atol(argv[1]);
    unsigned minDepth = 4;
    unsigned maxDepth = minDepth + 2 > N ? minDepth + 2 : N;
    unsigned stretchDepth = maxDepth + 1;

    printf("stretch tree of depth %u\t check: %li\n", stretchDepth,
           CheckAndDelete(BottomUpTree(stretchDepth)));

    treeNode* longLivedTree = BottomUpTree(maxDepth);

    for (unsigned depth = minDepth; depth <= maxDepth; depth += 2) {
        long iterations = 1L << (maxDepth - depth + minDepth);
        long check = 0;
        for (long i = 1; i <= iterations; i++)
            check += CheckAndDelete(BottomUpTree(depth));
        printf("%li\t trees of depth %u\t check: %li\n", iterations, depth, check);
    }

    printf("long lived tree of depth %u\t check: %li\n", maxDepth, CheckAndDelete(longLivedTree));
    return 0;
}
