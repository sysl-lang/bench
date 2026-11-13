# The Computer Language Benchmarks Game: binary-trees. Same algorithm as the C version:
# every node is its own heap allocation (a `ref`), and every tree is released node by node
# when the last reference to it goes (ORC reference counting).
import std/[os, strutils]

type Node = ref object
  left, right: Node

proc itemCheck(tree: Node): int =
  if tree.left == nil: 1
  else: 1 + itemCheck(tree.left) + itemCheck(tree.right)

proc bottomUpTree(depth: int): Node =
  if depth > 0:
    Node(left: bottomUpTree(depth - 1), right: bottomUpTree(depth - 1))
  else:
    Node()

let n = parseInt(paramStr(1))
const minDepth = 4
let maxDepth = max(minDepth + 2, n)
let stretchDepth = maxDepth + 1

block:
  let stretchTree = bottomUpTree(stretchDepth)
  echo "stretch tree of depth ", stretchDepth, "\t check: ", itemCheck(stretchTree)

let longLivedTree = bottomUpTree(maxDepth)

var depth = minDepth
while depth <= maxDepth:
  let iterations = 1 shl (maxDepth - depth + minDepth)
  var check = 0
  for _ in 1 .. iterations:
    let tempTree = bottomUpTree(depth)
    check += itemCheck(tempTree)
  echo iterations, "\t trees of depth ", depth, "\t check: ", check
  depth += 2

echo "long lived tree of depth ", maxDepth, "\t check: ", itemCheck(longLivedTree)
