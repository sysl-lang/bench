note
	description: "[
		regex-redux, written for this suite after the Benchmarks Game's programs: the regular
		expressions of the Gobo Eiffel Regexp Library (RX_PCRE_REGULAR_EXPRESSION, a PCRE-syntax
		backtracking matcher written in Eiffel), which ships with EiffelStudio. One thread.
	]"

class REGEXREDUX

create
	make

feature {NONE} -- Initialization

	make
			-- Print the count of every variant and the three lengths.
		local
			input, sequence, replaced: STRING
			re: RX_PCRE_REGULAR_EXPRESSION
			i: INTEGER
		do
			input := standard_input_text
			create re.make

				-- `.' does not match a newline, as in Perl.
			re.compile (">.*%N|%N")
			check re.is_compiled end
			re.match (input)
			sequence := re.replace_all ("")

			across variants as v loop
				io.put_string (v)
				io.put_character (' ')
				io.put_integer (match_count (re, v, sequence))
				io.put_new_line
			end

			replaced := sequence
			from
				i := substitutions.lower
			invariant
				in_range: substitutions.lower <= i and i <= substitutions.upper + 1
			until
				i > substitutions.upper
			loop
				re.compile (substitutions [i])
				check re.is_compiled end
				re.match (replaced)
				replaced := re.replace_all (replacements [i])
				i := i + 1
			variant
				substitutions.upper + 1 - i
			end

			io.put_new_line
			io.put_integer (input.count)
			io.put_new_line
			io.put_integer (sequence.count)
			io.put_new_line
			io.put_integer (replaced.count)
			io.put_new_line
		end

feature {NONE} -- Implementation

	variants: ARRAY [STRING]
			-- Each pattern and its reverse complement, with a wildcard in one position.
		once
			Result := <<"agggtaaa|tttaccct", "[cgt]gggtaaa|tttaccc[acg]", "a[act]ggtaaa|tttacc[agt]t",
				"ag[act]gtaaa|tttac[agt]ct", "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
				"agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct", "agggtaa[cgt]|[acg]ttaccct">>
		end

	substitutions: ARRAY [STRING]
			-- The IUB patterns, applied one after another.
		once
			Result := <<"tHa[Nt]", "aND|caN|Ha[DS]|WaS", "a[NSt]|BY", "<[^>]*>", "\|[^|][^|]*\|">>
		ensure
			five: Result.count = 5
		end

	replacements: ARRAY [STRING]
			-- What each of `substitutions' is replaced by.
		once
			Result := <<"<4>", "<3>", "<2>", "|", "-">>
		ensure
			one_each: Result.count = substitutions.count and Result.lower = substitutions.lower
		end

	match_count (re: RX_PCRE_REGULAR_EXPRESSION; pattern, subject: STRING): INTEGER
			-- How many times `pattern' matches `subject', the matches not overlapping.
		require
			pattern_not_empty: not pattern.is_empty
		do
			re.compile (pattern)
			check re.is_compiled end
			from
				re.match (subject)
			until
				not re.has_matched
			loop
				Result := Result + 1
				re.match_unbounded_substring (subject, re.captured_end_position (0) + 1, subject.count)
			variant
				subject.count + 1 - re.subject_start
			end
		ensure
			not_negative: Result >= 0
		end

	standard_input_text: STRING
			-- Everything on standard input.
		do
			create Result.make (1048576)
			from
				io.input.read_stream (65536)
			until
				io.input.last_string.is_empty
			loop
				Result.append (io.input.last_string)
				io.input.read_stream (65536)
			end
		end

end
