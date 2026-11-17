note
	description: "[
		pi digits by Gibbons' unbounded spigot: a port of the Benchmarks Game C program (Mr Ledrug) to Eiffel.
		The integers are GMP's, reached through inline C externals over gmp.h; each `mpz_t' is a block
		allocated once and owned by this object.
	]"

class PIDIGITS

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Write the first n digits of pi, n the first argument (default 27), ten to a line.
		local
			n, i, d: INTEGER
			k: NATURAL_64
			line: STRING
		do
			n := 27
			if argument_count > 0 then
				n := argument (1).to_integer
			end
			tmp1 := new_mpz (0)
			tmp2 := new_mpz (0)
			acc := new_mpz (0)
			den := new_mpz (1)
			num := new_mpz (1)
			create line.make (16)
			from
			invariant
				digits_written: i >= 0 and i <= n
			until
				i >= n
			loop
				k := k + 1
				next_term (k)
				if c_mpz_cmp (num, acc) <= 0 then
					d := extract_digit (3)
					if d = extract_digit (4) then
						line.append_character (('0').plus (d))
						i := i + 1
						if i \\ 10 = 0 then
							line.append ("%T:")
							line.append_integer (i)
							line.append_character ('%N')
							io.put_string (line)
							line.wipe_out
						end
						eliminate_digit (d)
					end
				end
			end
			if n \\ 10 /= 0 then
				line.append (create {STRING}.make_filled (' ', 10 - n \\ 10))
				line.append ("%T:")
				line.append_integer (n)
				line.append_character ('%N')
				io.put_string (line)
			end
		end

feature {NONE} -- The spigot

	tmp1, tmp2, acc, den, num: POINTER
			-- GMP integers.

	extract_digit (nth: INTEGER): INTEGER
			-- (num * nth + acc) // den.
		require
			nth_is_three_or_four: nth = 3 or nth = 4
		do
			-- joggling between tmp1 and tmp2, so GMP won't have to use temp buffers
			c_mpz_mul_ui (tmp1, num, nth.to_natural_64)
			c_mpz_add (tmp2, tmp1, acc)
			c_mpz_tdiv_q (tmp1, tmp2, den)
			Result := c_mpz_get_ui (tmp1).to_integer_32
		ensure
			a_digit: Result >= 0 and Result <= 9
		end

	eliminate_digit (d: INTEGER)
			-- Take the digit `d' off the accumulated fraction.
		require
			a_digit: d >= 0 and d <= 9
		do
			c_mpz_submul_ui (acc, den, d.to_natural_64)
			c_mpz_mul_ui (acc, acc, 10)
			c_mpz_mul_ui (num, num, 10)
		end

	next_term (k: NATURAL_64)
			-- Compose the `k'th term of the series into the fraction.
		require
			positive: k > 0
		local
			k2: NATURAL_64
		do
			k2 := k * 2 + 1
			c_mpz_addmul_ui (acc, num, 2)
			c_mpz_mul_ui (acc, acc, k2)
			c_mpz_mul_ui (den, den, k2)
			c_mpz_mul_ui (num, num, k)
		end

feature {NONE} -- GMP

	new_mpz (v: NATURAL_64): POINTER
			-- A fresh GMP integer holding `v'.
		external
			"C inline use <gmp.h>, <stdlib.h>"
		alias
			"{
				mpz_ptr z = malloc (sizeof (__mpz_struct));
				mpz_init_set_ui (z, (unsigned long) $v);
				return z;
			}"
		end

	c_mpz_add (r, a, b: POINTER)
		external
			"C inline use <gmp.h>"
		alias
			"mpz_add ((mpz_ptr) $r, (mpz_srcptr) $a, (mpz_srcptr) $b)"
		end

	c_mpz_mul_ui (r, a: POINTER; b: NATURAL_64)
		external
			"C inline use <gmp.h>"
		alias
			"mpz_mul_ui ((mpz_ptr) $r, (mpz_srcptr) $a, (unsigned long) $b)"
		end

	c_mpz_addmul_ui (r, a: POINTER; b: NATURAL_64)
		external
			"C inline use <gmp.h>"
		alias
			"mpz_addmul_ui ((mpz_ptr) $r, (mpz_srcptr) $a, (unsigned long) $b)"
		end

	c_mpz_submul_ui (r, a: POINTER; b: NATURAL_64)
		external
			"C inline use <gmp.h>"
		alias
			"mpz_submul_ui ((mpz_ptr) $r, (mpz_srcptr) $a, (unsigned long) $b)"
		end

	c_mpz_tdiv_q (q, n, d: POINTER)
		external
			"C inline use <gmp.h>"
		alias
			"mpz_tdiv_q ((mpz_ptr) $q, (mpz_srcptr) $n, (mpz_srcptr) $d)"
		end

	c_mpz_get_ui (x: POINTER): NATURAL_64
		external
			"C inline use <gmp.h>"
		alias
			"return (EIF_NATURAL_64) mpz_get_ui ((mpz_srcptr) $x);"
		end

	c_mpz_cmp (a, b: POINTER): INTEGER
		external
			"C inline use <gmp.h>"
		alias
			"return (EIF_INTEGER) mpz_cmp ((mpz_srcptr) $a, (mpz_srcptr) $b);"
		end

invariant
	allocated: tmp1 /= default_pointer implies (acc /= default_pointer and den /= default_pointer and num /= default_pointer)

end
