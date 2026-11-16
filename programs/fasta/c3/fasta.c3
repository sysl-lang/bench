// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (by Drake Diedrich) to C3.
module fasta;
import std::io;
import libc;

const uint IM = 139968;
const uint IA = 3877;
const uint IC = 29573;
const uint SEED = 42;
const int LINELEN = 60;

uint seed = SEED;

fn double fasta_rand(double max) @inline
{
	seed = (seed * IA + IC) % IM;
	return max * seed / IM;
}

String alu =
	"GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
	"GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
	"CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
	"ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
	"GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
	"AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
	"AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

String iub = "acgtBDHKMNRSVWY";
double[15] iub_p = {
	0.27, 0.12, 0.12, 0.27,
	0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02
};

String homosapiens = "acgt";
double[4] homosapiens_p = {
	0.3029549426680,
	0.1979883004921,
	0.1975473066391,
	0.3015094502008
};

fn void repeat_fasta(String seq, int n)
{
	int len = (int)seq.len;
	char* buffer = mem::alloc_array(char, (usz)(len + LINELEN));
	mem::copy(buffer, seq.ptr, len);
	mem::copy(buffer + len, seq.ptr, LINELEN);

	libc::CFile out = libc::stdout();
	int t = 0;
	int whole_lines = n / LINELEN;
	for (int i = 0; i < whole_lines; i++)
	{
		int wrote = (int)libc::fwrite(&buffer[t % len], 1, LINELEN, out);
		libc::putc('\n', out);
		t += wrote;
	}
	libc::fwrite(&buffer[t % len], 1, (usz)(n - t), out);
	mem::free(buffer);
	if (n % LINELEN != 0) libc::putc('\n', out);
}

fn int linear_lookup(int len, double* p, double v) @inline
{
	int i = 0;
	for (int j = 0; j < len - 1; j++) if (v > p[j]) i++;
	return i;
}

fn void random_fasta(String symb, double* probability, int n)
{
	int len = (int)symb.len;
	double* p = mem::alloc_array(double, (usz)len);
	char* buffer = mem::alloc_array(char, LINELEN + 2);
	buffer[LINELEN] = '\n';
	libc::CFile out = libc::stdout();

	p[0] = probability[0];
	for (int i = 1; i < len; i++) p[i] = probability[i] + p[i - 1];

	int lines = n / LINELEN;
	for (int i = 0; i < lines; i++)
	{
		for (int k = 0; k < LINELEN; k++)
		{
			double v = fasta_rand(1.0);
			buffer[k] = symb[linear_lookup(len, p, v)];
		}
		libc::fwrite(buffer, 1, LINELEN + 1, out);
	}
	int remainder = n - lines * LINELEN;
	for (int k = 0; k < remainder; k++)
	{
		double v = fasta_rand(1.0);
		buffer[k] = symb[linear_lookup(len, p, v)];
	}
	libc::fwrite(buffer, 1, (usz)remainder, out);
	if (n % LINELEN != 0) libc::putc('\n', out);
	mem::free(buffer);
	mem::free(p);
}

fn int main(String[] args)
{
	int n = 1000;
	if (args.len > 1) n = args[1].to_int()!!;

	libc::CFile out = libc::stdout();
	libc::fputs(">ONE Homo sapiens alu\n", out);
	repeat_fasta(alu, n * 2);

	libc::fputs(">TWO IUB ambiguity codes\n", out);
	random_fasta(iub, &iub_p, n * 3);

	libc::fputs(">THREE Homo sapiens frequency\n", out);
	random_fasta(homosapiens, &homosapiens_p, n * 5);
	libc::fflush(out);
	return 0;
}
