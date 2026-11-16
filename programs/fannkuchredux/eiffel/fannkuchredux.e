note
	description: "Fannkuch-redux: a port of the Benchmarks Game C program (Ledrug Katz) to Eiffel."

class FANNKUCHREDUX

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Print the checksum and the maximum number of flips over the permutations of the size given as the first argument.
		local
			i: INTEGER
		do
			max_n := argument (1).to_integer
			create s.make_filled (0, 0, 15)
			create t.make_filled (0, 0, 15)
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= max_n
			variant
				max_n - i
			until
				i >= max_n
			loop
				s.put (i, i)
				i := i + 1
			end
			tk (max_n)
			io.put_string (checksum.out + "%NPfannkuchen(" + max_n.out + ") = " + maxflips.out + "%N")
		end

feature {NONE} -- Access

	s, t: ARRAY [INTEGER]
			-- The permutation being generated and the copy that is flipped.

	max_n: INTEGER

	maxflips: INTEGER

	checksum: INTEGER

	odd: BOOLEAN

feature {NONE} -- Basic operations

	flip: INTEGER
			-- Number of flips of the first element needed to bring 0 to the front of a copy of `s'.
		local
			k, x, y, c: INTEGER
			done: BOOLEAN
		do
			from
				k := 0
			invariant
				k_in_range: k >= 0 and k <= max_n
			variant
				max_n - k
			until
				k >= max_n
			loop
				t.put (s.item (k), k)
				k := k + 1
			end
			Result := 1
			from
			until
				done
			loop
				x := 0
				y := t.item (0)
				from
				invariant
					ends_in_range: x >= 0 and y < max_n
				variant
					y - x + 1
				until
					x >= y
				loop
					c := t.item (x)
					t.put (t.item (y), x)
					x := x + 1
					t.put (c, y)
					y := y - 1
				end
				Result := Result + 1
				done := t.item (t.item (0)) = 0
			end
		ensure
			at_least_one: Result >= 1
		end

	rotate (n: INTEGER)
			-- Rotate the first `n' + 1 elements of `s' left by one.
		require
			n_in_range: n >= 0 and n < max_n
		local
			c, i: INTEGER
		do
			c := s.item (0)
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= n + 1
			variant
				n + 1 - i
			until
				i > n
			loop
				s.put (s.item (i), i - 1)
				i := i + 1
			end
			s.put (c, n)
		end

	tk (n: INTEGER)
			-- Tompkin-Paige iterative permutation generation.
		local
			i, f: INTEGER
			c: ARRAY [INTEGER]
		do
			create c.make_filled (0, 0, 15)
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= n
			until
				i >= n
			loop
				rotate (i)
				if c.item (i) >= i then
					c.put (0, i)
					i := i + 1
				else
					c.put (c.item (i) + 1, i)
					i := 1
					odd := not odd
					if s.item (0) /= 0 then
						if s.item (s.item (0)) /= 0 then
							f := flip
						else
							f := 1
						end
						if f > maxflips then
							maxflips := f
						end
						if odd then
							checksum := checksum - f
						else
							checksum := checksum + f
						end
					end
				end
			end
		end

invariant
	arrays_sized: s.count = 16 and t.count = 16

end
