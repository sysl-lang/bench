note
	description: "Spectral norm of an infinite matrix: a port of the Benchmarks Game C program (Sebastien Loisel) to Eiffel."

class SPECTRALNORM

inherit
	DOUBLE_MATH

	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Print the spectral norm of the matrix truncated to the size given as the first argument (default 100).
		local
			n, i: INTEGER
			u, v: ARRAY [REAL_64]
			vbv, vv: REAL_64
			format: FORMAT_DOUBLE
			text: STRING
		do
			if argument_count = 1 then
				n := argument (1).to_integer
			else
				n := 100
			end
			create u.make_filled (1.0, 0, n - 1)
			create v.make_filled (0.0, 0, n - 1)
			from
				i := 0
			invariant
				rounds_in_range: i >= 0 and i <= 10
			variant
				10 - i
			until
				i >= 10
			loop
				eval_ata_times_u (n, u, v)
				eval_ata_times_u (n, v, u)
				i := i + 1
			end
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= n
			variant
				n - i
			until
				i >= n
			loop
				vbv := vbv + u.item (i) * v.item (i)
				vv := vv + v.item (i) * v.item (i)
				i := i + 1
			end
			create format.make (20, 9)
			format.left_justify
			text := format.formatted (sqrt (vbv / vv))
			text.right_adjust
			io.put_string (text)
			io.put_new_line
		end

feature {NONE} -- Matrix operations

	eval_a (i, j: INTEGER): REAL_64
			-- Entry (`i', `j') of the matrix.
		require
			indices_non_negative: i >= 0 and j >= 0
		do
			Result := 1.0 / ((i + j) * (i + j + 1) // 2 + i + 1).to_double
		end

	eval_a_times_u (n: INTEGER; u, au: ARRAY [REAL_64])
			-- Set `au' to the matrix times `u'.
		require
			sizes: u.count = n and au.count = n
		local
			i, j: INTEGER
		do
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= n
			variant
				n - i
			until
				i >= n
			loop
				au.put (0.0, i)
				from
					j := 0
				invariant
					j_in_range: j >= 0 and j <= n
				variant
					n - j
				until
					j >= n
				loop
					au.put (au.item (i) + eval_a (i, j) * u.item (j), i)
					j := j + 1
				end
				i := i + 1
			end
		end

	eval_at_times_u (n: INTEGER; u, au: ARRAY [REAL_64])
			-- Set `au' to the transposed matrix times `u'.
		require
			sizes: u.count = n and au.count = n
		local
			i, j: INTEGER
		do
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= n
			variant
				n - i
			until
				i >= n
			loop
				au.put (0.0, i)
				from
					j := 0
				invariant
					j_in_range: j >= 0 and j <= n
				variant
					n - j
				until
					j >= n
				loop
					au.put (au.item (i) + eval_a (j, i) * u.item (j), i)
					j := j + 1
				end
				i := i + 1
			end
		end

	eval_ata_times_u (n: INTEGER; u, atau: ARRAY [REAL_64])
			-- Set `atau' to the transposed matrix times the matrix times `u'.
		require
			sizes: u.count = n and atau.count = n
		local
			v: ARRAY [REAL_64]
		do
			create v.make_filled (0.0, 0, n - 1)
			eval_a_times_u (n, u, v)
			eval_at_times_u (n, v, atau)
		end

end
