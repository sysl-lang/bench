note
	description: "Reverse-complement of FASTA sequences: a port of the Benchmarks Game C program (Bob W) to Eiffel."

class REVCOMP

create
	make

feature {NONE} -- Initialization

	make
			-- Copy standard input to standard output, writing each sequence reverse-complemented.
		local
			a_line: STRING
		do
			build_table
			create seq.make (1048576)
			create result_text.make (1048576)
			from
				io.read_line
			until
				io.input.end_of_file
			loop
				a_line := io.last_string
				if a_line.count > 0 and then a_line.item (1) = '>' then
					flush
					io.put_string (a_line)
					io.put_new_line
				else
					append_complemented (a_line)
				end
				io.read_line
			end
			flush
		end

feature {NONE} -- Access

	table: ARRAY [CHARACTER_8]
			-- The complement of each character code; `%U' for a character that is dropped.

	seq: STRING
			-- The complemented characters of the sequence being read.

	result_text: STRING
			-- Buffer for the reversed sequence.

feature {NONE} -- Basic operations

	build_table
			-- Fill `table': both cases of each IUB code map to the upper-case complement.
		local
			pairs: STRING
			i: INTEGER
			from_char, to_char: CHARACTER_8
		do
			create table.make_filled ('%U', 0, 255)
			pairs := "ATBVCGDHGCHDKMMKNNRYSSTAVBWWYR"
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= pairs.count + 1
			variant
				pairs.count + 1 - i
			until
				i > pairs.count
			loop
				from_char := pairs.item (i)
				to_char := pairs.item (i + 1)
				table.put (to_char, from_char.code)
				table.put (to_char, from_char.lower.code)
				i := i + 2
			end
		ensure
			table_sized: table.count = 256
		end

	append_complemented (a_line: STRING)
			-- Append the complement of each character of `a_line' that has one to `seq'.
		local
			i: INTEGER
			c: CHARACTER_8
		do
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= a_line.count + 1
			variant
				a_line.count + 1 - i
			until
				i > a_line.count
			loop
				c := table.item (a_line.item (i).code)
				if c /= '%U' then
					seq.append_character (c)
				end
				i := i + 1
			end
		end

	flush
			-- Write `seq' reversed, 60 characters to a line, and start a new sequence.
		local
			p, x, k: INTEGER
		do
			result_text.wipe_out
			from
				p := seq.count
			invariant
				p_in_range: p >= 0 and p <= seq.count
			variant
				p
			until
				p <= 0
			loop
				x := p.min (60)
				from
					k := 0
				invariant
					k_in_range: k >= 0 and k <= x
				variant
					x - k
				until
					k >= x
				loop
					result_text.append_character (seq.item (p - k))
					k := k + 1
				end
				result_text.append_character ('%N')
				p := p - x
			end
			io.put_string (result_text)
			seq.wipe_out
		ensure
			sequence_consumed: seq.count = 0
		end

end
