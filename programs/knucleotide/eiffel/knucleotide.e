note
	description: "K-nucleotide frequencies: a port of the Benchmarks Game C program (Jeremy Zerfas) to Eiffel, counting into a HASH_TABLE keyed by the 2k-bit code of each oligonucleotide."

class KNUCLEOTIDE

create
	make

feature {NONE} -- Initialization

	make
			-- Read a FASTA file from standard input and report on its third sequence.
		do
			create poly.make_filled (0, 1, 1048576)
			from
				io.read_line
			until
				io.input.end_of_file or else io.last_string.starts_with (">THREE")
			loop
				io.read_line
			end
			from
				io.read_line
			until
				io.input.end_of_file or else (io.last_string.count > 0 and then io.last_string.item (1) = '>')
			loop
				append_line (io.last_string)
				io.read_line
			end
			generate_frequencies (1)
			generate_frequencies (2)
			across
				<<"GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT">> as oligonucleotide
			loop
				generate_count (oligonucleotide)
			end
		end

feature {NONE} -- Access

	poly: ARRAY [NATURAL_8]
			-- The codes of the nucleotides of the third sequence, indexed from 1 to `length'.

	length: INTEGER
			-- Number of nucleotides in `poly'.

	letters: STRING = "ACGT"

feature {NONE} -- Basic operations

	code_for_nucleotide (c: CHARACTER_8): NATURAL_8
			-- The code of nucleotide `c': A, C, G and T are 0 to 3.
		do
			inspect c
			when 'A', 'a' then
				Result := 0
			when 'C', 'c' then
				Result := 1
			when 'G', 'g' then
				Result := 2
			else
				Result := 3
			end
		end

	append_line (a_line: STRING)
			-- Append the nucleotides of `a_line' to `poly'.
		local
			i: INTEGER
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
				length := length + 1
				if length > poly.count then
					poly.conservative_resize_with_default (0, 1, poly.count * 2)
				end
				poly.put (code_for_nucleotide (a_line.item (i)), length)
				i := i + 1
			end
		ensure
			grown: length >= old length
		end

	count_oligonucleotides (table: HASH_TABLE [INTEGER, INTEGER_64]; oligo_length: INTEGER)
			-- Add the count of every oligonucleotide of `oligo_length' in `poly' to `table'.
		require
			length_sensible: oligo_length >= 1 and oligo_length <= 31
		local
			key, mask: INTEGER_64
			i: INTEGER
		do
			mask := ((1).to_integer_64.bit_shift_left (2 * oligo_length)) - 1
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= oligo_length
			variant
				oligo_length - i
			until
				i >= oligo_length
			loop
				key := key.bit_shift_left (2).bit_and (mask).bit_or (poly.item (i).to_integer_64)
				i := i + 1
			end
			from
				i := oligo_length
			invariant
				i_in_range: i >= oligo_length and i <= length + 1
			variant
				length + 1 - i
			until
				i > length
			loop
				key := key.bit_shift_left (2).bit_and (mask).bit_or (poly.item (i).to_integer_64)
				table.search (key)
				if table.found then
					table.replace (table.found_item + 1, key)
				else
					table.put (1, key)
				end
				i := i + 1
			end
		end

	generate_frequencies (oligo_length: INTEGER)
			-- Print the frequency of every oligonucleotide of `oligo_length', most frequent first.
		require
			length_sensible: oligo_length >= 1 and oligo_length <= 4
		local
			table: HASH_TABLE [INTEGER, INTEGER_64]
			keys: ARRAY [INTEGER_64]
			values: ARRAY [INTEGER]
			size, i, j, value: INTEGER
			key: INTEGER_64
			name: STRING
			percent: REAL_32
			format: FORMAT_DOUBLE
			text: STRING
		do
			create table.make (64)
			count_oligonucleotides (table, oligo_length)
			size := table.count
			create keys.make_filled (0, 1, size)
			create values.make_filled (0, 1, size)
			from
				table.start
				i := 0
			until
				table.after
			loop
				i := i + 1
				keys.put (table.key_for_iteration, i)
				values.put (table.item_for_iteration, i)
				table.forth
			end
				-- Order by value, largest first, then by key, smallest first. There are at most
				-- 4 to the power of `oligo_length' elements, so an insertion sort suffices.
			from
				i := 2
			invariant
				i_in_range: i >= 2 and i <= size + 1
			variant
				size + 1 - i
			until
				i > size
			loop
				key := keys.item (i)
				value := values.item (i)
				from
					j := i - 1
				invariant
					j_in_range: j >= 0 and j < i
				variant
					j + 1
				until
					j < 1 or else not (values.item (j) < value or else (values.item (j) = value and keys.item (j) > key))
				loop
					keys.put (keys.item (j), j + 1)
					values.put (values.item (j), j + 1)
					j := j - 1
				end
				keys.put (key, j + 1)
				values.put (value, j + 1)
				i := i + 1
			end
			create format.make (20, 3)
			format.left_justify
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= size + 1
			variant
				size + 1 - i
			until
				i > size
			loop
				create name.make_filled (' ', oligo_length)
				key := keys.item (i)
				from
					j := oligo_length
				invariant
					j_in_range: j >= 0 and j <= oligo_length
				variant
					j
				until
					j < 1
				loop
					name.put (letters.item (key.bit_and (3).to_integer_32 + 1), j)
					key := key.bit_shift_right (2)
					j := j - 1
				end
				percent := ({REAL_32} 100.0) * values.item (i).to_real / (length - oligo_length + 1).to_real
				text := format.formatted (percent.to_double)
				text.right_adjust
				io.put_string (name + " " + text + "%N")
				i := i + 1
			end
			io.put_new_line
		end

	generate_count (oligonucleotide: STRING)
			-- Print how many times `oligonucleotide' occurs in `poly'.
		local
			table: HASH_TABLE [INTEGER, INTEGER_64]
			key: INTEGER_64
			i, count: INTEGER
		do
			create table.make (1024)
			count_oligonucleotides (table, oligonucleotide.count)
			from
				i := 1
			invariant
				i_in_range: i >= 1 and i <= oligonucleotide.count + 1
			variant
				oligonucleotide.count + 1 - i
			until
				i > oligonucleotide.count
			loop
				key := key.bit_shift_left (2).bit_or (code_for_nucleotide (oligonucleotide.item (i)).to_integer_64)
				i := i + 1
			end
			table.search (key)
			if table.found then
				count := table.found_item
			end
			io.put_string (count.out + "%T" + oligonucleotide + "%N")
		end

end
