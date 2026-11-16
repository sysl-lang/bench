note
	description: "FASTA generation: a port of the Benchmarks Game C program (Drake Diedrich) to Eiffel."

class FASTA

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Write the three FASTA sequences for the scale given as the first argument (default 1000).
		local
			n: INTEGER
		do
			n := 1000
			if argument_count > 0 then
				n := argument (1).to_integer
			end
			seed := initial_seed
			create line.make (line_length + 1)
			io.put_string (">ONE Homo sapiens alu%N")
			repeat_fasta (alu, n * 2)
			io.put_string (">TWO IUB ambiguity codes%N")
			random_fasta (iub, iub_p, n * 3)
			io.put_string (">THREE Homo sapiens frequency%N")
			random_fasta (homosapiens, homosapiens_p, n * 5)
		end

feature {NONE} -- Constants

	im: INTEGER = 139968

	ia: INTEGER = 3877

	ic: INTEGER = 29573

	initial_seed: INTEGER = 42

	line_length: INTEGER = 60

	alu: STRING = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

	iub: STRING = "acgtBDHKMNRSVWY"

	iub_p: ARRAY [REAL_64]
			-- Probabilities of the symbols of `iub'.
		once
			Result := <<0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02>>
		end

	homosapiens: STRING = "acgt"

	homosapiens_p: ARRAY [REAL_64]
			-- Probabilities of the symbols of `homosapiens'.
		once
			Result := <<0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008>>
		end

feature {NONE} -- Access

	seed: INTEGER

	line: STRING
			-- Buffer for the line being written.

feature {NONE} -- Basic operations

	fasta_rand (max: REAL_64): REAL_64
			-- The next pseudo-random number in [0, `max').
		do
			seed := (seed * ia + ic) \\ im
			Result := max * seed.to_double / im.to_double
		end

	repeat_fasta (seq: STRING; n: INTEGER)
			-- Write `n' characters of `seq' repeated, in lines of `line_length'.
		require
			sequence_longer_than_a_line: seq.count > line_length
			n_non_negative: n >= 0
		local
			buffer: STRING
			len, t, i, whole_lines, start: INTEGER
		do
			len := seq.count
			buffer := seq + seq.substring (1, line_length)
			whole_lines := n // line_length
			from
				i := 0
			invariant
				line_in_range: i >= 0 and i <= whole_lines
			variant
				whole_lines - i
			until
				i >= whole_lines
			loop
				start := t \\ len + 1
				line.wipe_out
				line.append_substring (buffer, start, start + line_length - 1)
				line.append_character ('%N')
				io.put_string (line)
				t := t + line_length
				i := i + 1
			end
			if n - t > 0 then
				start := t \\ len + 1
				line.wipe_out
				line.append_substring (buffer, start, start + n - t - 1)
				line.append_character ('%N')
				io.put_string (line)
			end
		end

	linear_lookup (len: INTEGER; p: ARRAY [REAL_64]; v: REAL_64): INTEGER
			-- Index of the symbol whose cumulative probability bracket holds `v'.
		local
			j: INTEGER
		do
			from
				j := 0
			invariant
				j_in_range: j >= 0 and j <= len - 1
			variant
				len - 1 - j
			until
				j >= len - 1
			loop
				if v > p.item (j) then
					Result := Result + 1
				end
				j := j + 1
			end
		ensure
			in_range: Result >= 0 and Result < len
		end

	random_fasta (symb: STRING; probability: ARRAY [REAL_64]; n: INTEGER)
			-- Write `n' random symbols of `symb', chosen with `probability', in lines of `line_length'.
		require
			one_probability_each: probability.count = symb.count
			n_non_negative: n >= 0
		local
			len, i, k, lines, remainder: INTEGER
			p: ARRAY [REAL_64]
		do
			len := symb.count
			create p.make_filled (0.0, 0, len - 1)
			p.put (probability.item (probability.lower), 0)
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= len
			variant
				len - i
			until
				i >= len
			loop
				p.put (probability.item (probability.lower + i) + p.item (i - 1), i)
				i := i + 1
			end
			lines := n // line_length
			from
				i := 0
			invariant
				line_in_range: i >= 0 and i <= lines
			variant
				lines - i
			until
				i >= lines
			loop
				line.wipe_out
				from
					k := 0
				invariant
					k_in_range: k >= 0 and k <= line_length
				variant
					line_length - k
				until
					k >= line_length
				loop
					line.append_character (symb.item (linear_lookup (len, p, fasta_rand (1.0)) + 1))
					k := k + 1
				end
				line.append_character ('%N')
				io.put_string (line)
				i := i + 1
			end
			remainder := n - lines * line_length
			if remainder > 0 then
				line.wipe_out
				from
					k := 0
				invariant
					k_in_range: k >= 0 and k <= remainder
				variant
					remainder - k
				until
					k >= remainder
				loop
					line.append_character (symb.item (linear_lookup (len, p, fasta_rand (1.0)) + 1))
					k := k + 1
				end
				line.append_character ('%N')
				io.put_string (line)
			end
		end

end
