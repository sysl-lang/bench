note
	description: "Binary trees: a port of the Benchmarks Game C program (Kevin Carson) to Eiffel. The trees are reclaimed by the garbage collector."

class BINARYTREES

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Build and check trees of the depths the Benchmarks Game asks for, up to the first argument.
		local
			n, depth, min_depth, max_depth, stretch_depth, i, iterations: INTEGER
			check_sum: INTEGER_64
			long_lived_tree, temp_tree: TREE_NODE
		do
			n := argument (1).to_integer
			min_depth := 4
			if min_depth + 2 > n then
				max_depth := min_depth + 2
			else
				max_depth := n
			end
			stretch_depth := max_depth + 1

			temp_tree := bottom_up_tree (stretch_depth)
			io.put_string ("stretch tree of depth " + stretch_depth.out + "%T check: " + temp_tree.item_check.out + "%N")

			long_lived_tree := bottom_up_tree (max_depth)

			from
				depth := min_depth
			invariant
				depth_in_range: depth >= min_depth and depth <= max_depth + 2
			variant
				max_depth + 2 - depth
			until
				depth > max_depth
			loop
				iterations := (1).bit_shift_left (max_depth - depth + min_depth)
				check_sum := 0
				from
					i := 1
				invariant
					i_in_range: i >= 1 and i <= iterations + 1
				variant
					iterations + 1 - i
				until
					i > iterations
				loop
					temp_tree := bottom_up_tree (depth)
					check_sum := check_sum + temp_tree.item_check
					i := i + 1
				end
				io.put_string (iterations.out + "%T trees of depth " + depth.out + "%T check: " + check_sum.out + "%N")
				depth := depth + 2
			end

			io.put_string ("long lived tree of depth " + max_depth.out + "%T check: " + long_lived_tree.item_check.out + "%N")
		end

feature {NONE} -- Basic operations

	bottom_up_tree (depth: INTEGER): TREE_NODE
			-- A complete tree of the given `depth'.
		require
			depth_non_negative: depth >= 0
		do
			if depth > 0 then
				create Result.make (bottom_up_tree (depth - 1), bottom_up_tree (depth - 1))
			else
				create Result.make (Void, Void)
			end
		end

end
