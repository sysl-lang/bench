// The Computer Language Benchmarks Game: reverse-complement. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (revcomp.gcc-9, Jeremy Zerfas): the input is
// read whole; each record's output (its reverse complement in 60-column lines) is cut into chunks of
// lines that one thread per core fills; characters are complemented two at a time through a
// 65,536-entry table of byte pairs (gcc-9's idea, from roman blog's C++ program); and when a record
// is made of full 60-character lines (every fasta file is, but for its last line), the sequence is
// read straight from the input with no pass to remove the newlines, as gcc-9's fast path does. Any
// other record is first copied without its newlines. The whole output is written in one call.
module revcomp;
import std::thread;
import libc;

const long LINE = 60;

char[256] xtab;
// pair[b0 | b1 << 8] is the complement of the two bytes b0 b1 reversed: comp(b1) | comp(b0) << 8.
ushort[65536] pair;

// dst gets the reverse complement of the n bytes at src.
fn void rev_comp(char* dst, char* src, long n) @inline
{
	long i = 0;
	long e = n;
	while (e >= 2)
	{
		ushort v = mem::load((ushort*)(src + e - 2), 1);
		mem::store((ushort*)(dst + i), pair[v], 1);
		e -= 2;
		i += 2;
	}
	if (e == 1) dst[i] = xtab[src[0]];
}

// A record's sequence: either seq holds raw input in full 61-byte lines (raw), or it holds the
// sequence with its newlines removed.
struct Record
{
	char* seq;
	long len; // characters, without newlines
	bool raw;
}

struct Job
{
	Record r;
	char* dst;
	long first;
	long last;
}

// Output lines [first, last) of the record (each LINE characters and a newline, the last shorter).
fn int fill_lines(void* arg)
{
	Job* job = arg;
	Record r = job.r;
	for (long l = job.first; l < job.last; l++)
	{
		long end = r.len - l * LINE;
		long x = end < LINE ? end : LINE;
		long a = end - x;
		char* o = job.dst + l * (LINE + 1);
		if (!r.raw)
		{
			rev_comp(o, r.seq + a, x);
		}
		else
		{
			long la = a / LINE;
			long lb = (end - 1) / LINE;
			if (la == lb)
			{
				rev_comp(o, r.seq + a + la, x);
			}
			else
			{
				// Two raw lines: the later one's characters come first in the reversed output.
				long first_len = (la + 1) * LINE - a;
				rev_comp(o, r.seq + (la + 1) * (LINE + 1), x - first_len);
				rev_comp(o + x - first_len, r.seq + a + la, first_len);
			}
		}
		o[x] = '\n';
	}
	return 0;
}

int nthreads = 1;
Job[256] jobs;
Thread[256] threads;
char* out;
long olen;

fn void emit(Record r)
{
	long nlines = (r.len + LINE - 1) / LINE;
	char* dst = out + olen;
	long per = max(64L, (nlines + nthreads - 1) / nthreads);
	int count = 0;
	for (long first = 0; first < nlines; first += per)
	{
		jobs[count] = { r, dst, first, min(first + per, nlines) };
		count++;
	}
	for (int k = 1; k < count; k++) threads[k].create(&fill_lines, &jobs[k])!!;
	fill_lines(&jobs[0]);
	for (int k = 1; k < count; k++) (void)threads[k].join();
	olen += r.len + nlines;
}

fn void put(char* data, long n)
{
	mem::copy(out + olen, data, (usz)n);
	olen += n;
}

// The record whose sequence lines are the n bytes at body (each ending in a newline but perhaps the
// last).
fn Record record(char* body, long n, char* scratch)
{
	long m = n;
	if (m > 0 && body[m - 1] == '\n') m--;
	long lines = m / (LINE + 1) + 1;
	bool full = m > 0;
	for (long k = LINE; k < m; k += LINE + 1)
	{
		if (body[k] != '\n')
		{
			full = false;
			break;
		}
	}
	if (full)
	{
		for (long k = (lines - 1) * (LINE + 1); k < m; k++)
		{
			if (body[k] == '\n')
			{
				full = false;
				break;
			}
		}
	}
	if (full) return { body, m - (lines - 1), true };
	long j = 0;
	for (long k = 0; k < n; k++)
	{
		if (body[k] != '\n') scratch[j++] = body[k];
	}
	return { scratch, j, false };
}

fn int main(String[] args)
{
	String from = "ABCDGHKMNRSTVWY";
	String to = "TVGHCDMKNYSABWR";
	for (usz i = 0; i < from.len; i++)
	{
		xtab[from[i]] = to[i];
		xtab[from[i] + 32] = to[i];
	}
	for (int v = 0; v < 65536; v++) pair[v] = (ushort)xtab[v >> 8] | (ushort)xtab[v & 0xff] << 8;
	nthreads = min(max(thread::cpu::native_cpu(), 1), 256);

	long cap = 1 << 20;
	long len = 0;
	char* input = mem::malloc(cap);
	while (true)
	{
		if (len == cap)
		{
			cap *= 2;
			input = mem::realloc(input, cap);
		}
		long r = libc::read(0, input + len, (usz)(cap - len));
		if (r <= 0) break;
		len += r;
	}
	// The output is no longer than the input plus a newline per line and a final one.
	out = mem::malloc(len + len / LINE + 2);
	char* scratch = mem::malloc(len + 1);

	long pos = 0;
	while (pos < len)
	{
		// A header line, then the sequence up to the next '>' at a line start.
		long hend = pos;
		while (hend < len && input[hend] != '\n') hend++;
		if (hend < len) hend++;
		put(input + pos, hend - pos);
		long bend = hend;
		while (bend < len && !(input[bend] == '>' && input[bend - 1] == '\n')) bend++;
		Record rec = record(input + hend, bend - hend, scratch);
		if (rec.len > 0) emit(rec);
		pos = bend;
	}

	long off = 0;
	while (off < olen)
	{
		long r = libc::write(1, out + off, (usz)(olen - off));
		if (r <= 0) break;
		off += r;
	}
	return 0;
}
