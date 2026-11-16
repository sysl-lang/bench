note
	description: "A node of a binary tree whose two children are either both present or both absent."

class TREE_NODE

create
	make

feature {NONE} -- Initialization

	make (a_left, a_right: detachable TREE_NODE)
			-- Create a node with the given children.
		require
			both_or_neither: (a_left = Void) = (a_right = Void)
		do
			left := a_left
			right := a_right
		ensure
			left_set: left = a_left
			right_set: right = a_right
		end

feature -- Access

	left, right: detachable TREE_NODE
			-- The children.

feature -- Measurement

	item_check: INTEGER_64
			-- Number of nodes in the tree rooted here.
		do
			if attached left as l and then attached right as r then
				Result := 1 + l.item_check + r.item_check
			else
				Result := 1
			end
		ensure
			counted: Result >= 1
		end

invariant
	both_or_neither: (left = Void) = (right = Void)

end
