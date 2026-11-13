# The Computer Language Benchmarks Game: binary-trees. Same algorithm as the C version:
# every node is its own heap allocation (a mutable struct, reclaimed by Julia's garbage collector).

mutable struct Node
    left::Union{Node,Nothing}
    right::Union{Node,Nothing}
end

item_check(tree::Node)::Int =
    tree.left === nothing ? 1 : 1 + item_check(tree.left::Node) + item_check(tree.right::Node)

bottom_up_tree(depth::Int)::Node =
    depth > 0 ? Node(bottom_up_tree(depth - 1), bottom_up_tree(depth - 1)) : Node(nothing, nothing)

function main(n::Int)
    min_depth = 4
    max_depth = max(min_depth + 2, n)
    stretch_depth = max_depth + 1

    stretch_tree = bottom_up_tree(stretch_depth)
    println("stretch tree of depth ", stretch_depth, "\t check: ", item_check(stretch_tree))
    stretch_tree = nothing

    long_lived_tree = bottom_up_tree(max_depth)

    for depth in min_depth:2:max_depth
        iterations = 1 << (max_depth - depth + min_depth)
        check = 0
        for _ in 1:iterations
            check += item_check(bottom_up_tree(depth))
        end
        println(iterations, "\t trees of depth ", depth, "\t check: ", check)
    end

    println("long lived tree of depth ", max_depth, "\t check: ", item_check(long_lived_tree))
end

main(parse(Int, ARGS[1]))
