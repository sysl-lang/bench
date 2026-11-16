note
	description: "Mandelbrot set as a PBM bitmap: a port of the Benchmarks Game C program (Greg Buchholz) to Eiffel."

class MANDELBROT

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Write the bitmap of the square of the side given as the first argument to standard output.
		local
			w, h, xi, yi, i, bit_num, byte_acc: INTEGER
			x, y, zr, zi, cr, ci, tr, ti: REAL_64
		do
			w := argument (1).to_integer
			h := w
			io.put_string ("P4%N" + w.out + " " + h.out + "%N")
			from
				yi := 0
			invariant
				row_in_range: yi >= 0 and yi <= h
			variant
				h - yi
			until
				yi >= h
			loop
				y := yi.to_double
				from
					xi := 0
				invariant
					column_in_range: xi >= 0 and xi <= w
					bits_pending: bit_num >= 0 and bit_num < 8
				variant
					w - xi
				until
					xi >= w
				loop
					x := xi.to_double
					zr := 0.0
					zi := 0.0
					tr := 0.0
					ti := 0.0
					cr := 2.0 * x / w.to_double - 1.5
					ci := 2.0 * y / h.to_double - 1.0
					from
						i := 0
					invariant
						iteration_in_range: i >= 0 and i <= iterations
					variant
						iterations - i
					until
						i >= iterations or else tr + ti > limit * limit
					loop
						zi := 2.0 * zr * zi + ci
						zr := tr - ti + cr
						tr := zr * zr
						ti := zi * zi
						i := i + 1
					end
					byte_acc := byte_acc.bit_shift_left (1)
					if tr + ti <= limit * limit then
						byte_acc := byte_acc.bit_or (1)
					end
					bit_num := bit_num + 1
					if bit_num = 8 then
						io.put_character (byte_acc.to_character_8)
						byte_acc := 0
						bit_num := 0
					elseif xi = w - 1 then
						byte_acc := byte_acc.bit_shift_left (8 - w \\ 8)
						io.put_character (byte_acc.to_character_8)
						byte_acc := 0
						bit_num := 0
					end
					xi := xi + 1
				end
				yi := yi + 1
			end
		end

feature {NONE} -- Constants

	iterations: INTEGER = 50

	limit: REAL_64 = 2.0

end
