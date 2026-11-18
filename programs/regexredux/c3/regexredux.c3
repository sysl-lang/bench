// regex-redux, written for this suite after the Benchmarks Game's programs: C3's standard
// library regex (std::encoding::experimental::regex, POSIX ERE over musl's TNFA matcher).
// One thread.
module regexredux;
import std::io;
import std::encoding::experimental::regex;
import libc;

String[9] variants = {
	"agggtaaa|tttaccct",
	"[cgt]gggtaaa|tttaccc[acg]",
	"a[act]ggtaaa|tttacc[agt]t",
	"ag[act]gtaaa|tttac[agt]ct",
	"agg[act]taaa|ttta[agt]cct",
	"aggg[acg]aaa|ttt[cgt]ccct",
	"agggt[cgt]aa|tt[acg]accct",
	"agggta[cgt]a|t[acg]taccct",
	"agggtaa[cgt]|[acg]ttaccct",
};

String[2][5] substs = {
	{ "tHa[Nt]", "<4>" },
	{ "aND|caN|Ha[DS]|WaS", "<3>" },
	{ "a[NSt]|BY", "<2>" },
	{ "<[^>]*>", "|" },
	{ "\\|[^|][^|]*\\|", "-" },
};

fn String replace_all(String str, String pattern, String with)
{
	Regex re = regex::compile(mem, pattern, EXTENDED)!!;
	defer re.free();
	return re.replace(mem, str, with)!!;
}

fn int main(String[] args)
{
	// Read the whole of standard input.
	sz capacity = 1 << 20;
	sz length = 0;
	char* data = mem::alloc_array(char, (usz)capacity);
	libc::CFile in = libc::stdin();
	while (true)
	{
		if (length == capacity)
		{
			capacity *= 2;
			data = mem::realloc(data, (usz)capacity);
		}
		usz n = libc::fread(data + length, 1, (usz)(capacity - length), in);
		if (n == 0) break;
		length += (sz)n;
	}
	String input = (String)data[:length];

	// NEWLINE keeps `.` off the newline, as in the Perl-style patterns of the Game.
	Regex strip = regex::compile(mem, ">.*\n|\n", EXTENDED | NEWLINE)!!;
	String sequence = strip.replace(mem, input, "")!!;
	strip.free();

	foreach (v : variants)
	{
		Regex re = regex::compile(mem, v, EXTENDED)!!;
		Match[] all = re.find_all(mem, sequence)!!;
		io::printfn("%s %d", v, all.len);
		free(all);
		re.free();
	}

	String replaced = sequence;
	foreach (s : substs)
	{
		replaced = replace_all(replaced, s[0], s[1]);
	}

	io::printn();
	io::printn(input.len);
	io::printn(sequence.len);
	io::printn(replaced.len);
	return 0;
}
