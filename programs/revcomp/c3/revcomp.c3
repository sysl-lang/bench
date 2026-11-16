// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Bob W) to C3: lines are read with
// fgets into a growing buffer through a complement table, then written back in
// reverse, 60 to a line, with one fwrite per sequence.
module revcomp;
import libc;

const int LINE_SIZE = 82;

char[256] xtab;

fn void init_table()
{
	// Pairs of (letter, complement); both cases map to the upper-case complement.
	String pairs = "ATBVCGDHGCHDKMMKNNRYSSTAVBWWYR";
	for (usz i = 0; i < pairs.len; i += 2)
	{
		char from = pairs[i];
		char to = pairs[i + 1];
		xtab[from] = to;
		xtab[from + 32] = to;
	}
}

fn int main(String[] args)
{
	init_table();
	libc::CFile in = libc::stdin();
	libc::CFile out = libc::stdout();
	char[LINE_SIZE] line;
	char* seq = mem::alloc_array(char, 1 << 20);
	sz capacity = 1 << 20;
	char* result = mem::alloc_array(char, 1 << 20);
	sz result_capacity = 1 << 20;

	bool more = libc::fgets((char*)&line, LINE_SIZE, in) != null;
	while (more)
	{
		libc::fputs((ZString)&line, out);

		sz length = 0;
		while (true)
		{
			more = libc::fgets((char*)&line, LINE_SIZE, in) != null;
			if (!more || line[0] == '>') break;
			if (capacity - length < LINE_SIZE)
			{
				capacity *= 2;
				seq = mem::realloc(seq, (usz)capacity);
			}
			for (int i = 0; line[i] != 0; i++)
			{
				char c = xtab[line[i]];
				if (c != 0) seq[length++] = c;
			}
		}

		sz needed = length + length / 60 + 2;
		if (needed > result_capacity)
		{
			result_capacity = needed;
			result = mem::realloc(result, (usz)result_capacity);
		}
		sz o = 0;
		sz p = length;
		while (p > 0)
		{
			sz x = p < 60 ? p : 60;
			for (sz k = 0; k < x; k++) result[o + k] = seq[p - 1 - k];
			p -= x;
			o += x;
			result[o++] = '\n';
		}
		libc::fwrite(result, 1, (usz)o, out);
	}
	libc::fflush(out);
	return 0;
}
