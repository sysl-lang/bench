// The Computer Language Benchmarks Game: k-nucleotide. Original, written for this benchmark. It
// mirrors the Game's fastest C program (knucleotide.gcc, Jeremy Zerfas): one pass per oligonucleotide
// length over the encoded sequence, rolling the 2k-bit key one base at a time and counting it in a
// library hash table (C3's standard HashMap, its key hashed by gcc's `key ^ key >> 7` and loaded to
// khash's 77%). The seven tables (two frequency tables, five counts) are built at once, one thread
// each, as gcc builds them in OpenMP sections; each writes its report into its own buffer, and the
// buffers are printed in order.
module knucleotide;
import std::io;
import std::collections::map;
import std::thread;
import libc;

typedef Key = ulong;
fn uint Key.hash(self) => (uint)(self ^ (self >> 7));

alias OligoMap = HashMap{Key, uint};

struct Task
{
	char* poly;
	sz length;
	sz oligo_length;
	String oligo;
	char[1024] out;
	usz out_len;
}

fn void Task.print(&self, String format, args...)
{
	char[] s = io::bprintf(self.out[self.out_len..], format, ...args)!!;
	self.out_len += s.len;
}

struct Element
{
	ulong key;
	uint value;
}

// Codes for 'A', 'C', 'G' and 'T' indexed by the three low bits of the letter.
char[8] codes = { ' ', 0, ' ', 1, 3, ' ', ' ', 2 };
String letters = "ACGT";

fn char code_for_nucleotide(char c) @inline => codes[c & 0x7];

// Elements with larger values come first; equal values order by smaller key first.
fn int element_compare(void* l, void* r)
{
	Element* left = l;
	Element* right = r;
	if (left.value < right.value) return 1;
	if (left.value > right.value) return -1;
	return left.key > right.key ? 1 : -1;
}

fn void count_oligonucleotides(OligoMap* table, char* poly, sz length, sz oligo_length)
{
	ulong key = 0;
	ulong mask = (1UL << (2 * oligo_length)) - 1;
	for (sz i = 0; i < oligo_length - 1; i++) key = (key << 2 & mask) | poly[i];
	for (sz i = oligo_length - 1; i < length; i++)
	{
		key = (key << 2 & mask) | poly[i];
		uint* count = table.get_or_create_ref((Key)key);
		*count += 1;
	}
}

fn int generate_frequencies(void* arg)
{
	Task* task = arg;
	char* poly = task.poly;
	sz length = task.length;
	sz oligo_length = task.oligo_length;
	OligoMap table;
	table.init(mem, load_factor: 0.77);

	count_oligonucleotides(&table, poly, length, oligo_length);

	sz size = table.len();
	Element* elements = mem::alloc_array(Element, (usz)size);
	sz n = 0;
	table.@each(; Key key, uint value)
	{
		elements[n++] = { (ulong)key, value };
	};
	table.free();

	libc::qsort(elements, (usz)size, Element::size, &element_compare);

	for (sz i = 0; i < size; i++)
	{
		char[32] oligo;
		ulong key = elements[i].key;
		for (sz j =oligo_length - 1; j > -1; j--)
		{
			oligo[j] = letters[key & 0x3];
			key >>= 2;
		}
		String name = (String)oligo[:oligo_length];
		task.print("%s %.3f\n", name, 100.0f * (float)elements[i].value / (float)(length - oligo_length + 1));
	}
	mem::free(elements);
	task.print("\n");
	return 0;
}

fn int generate_count(void* arg)
{
	Task* task = arg;
	char* poly = task.poly;
	sz length = task.length;
	String oligo = task.oligo;
	sz oligo_length = (sz)oligo.len;
	OligoMap table;
	table.init(mem, load_factor: 0.77);

	count_oligonucleotides(&table, poly, length, oligo_length);

	ulong key = 0;
	for (sz i = 0; i < oligo_length; i++) key = (key << 2) | code_for_nucleotide(oligo[i]);

	uint count = 0;
	if (try found = table.get((Key)key)) count = found;
	task.print("%d\t%s\n", count, oligo);
	table.free();
	return 0;
}

fn int main(String[] args)
{
	libc::CFile in = libc::stdin();
	char[4096] buffer;

	// Find the start of the third polynucleotide.
	while (libc::fgets((char*)&buffer, 4096, in))
	{
		if (buffer[0] == '>' && buffer[1] == 'T' && buffer[2] == 'H' && buffer[3] == 'R' && buffer[4] == 'E' && buffer[5] == 'E') break;
	}

	sz capacity = 1048576;
	sz length = 0;
	char* poly = mem::alloc_array(char, (usz)capacity);

	while (libc::fgets((char*)&buffer, 4096, in) && buffer[0] != '>')
	{
		for (sz i = 0; buffer[i] != 0; i++)
		{
			if (buffer[i] != '\n') poly[length++] = code_for_nucleotide(buffer[i]);
		}
		if (capacity - length < 4096)
		{
			capacity *= 2;
			poly = mem::realloc(poly, (usz)capacity);
		}
	}

	String[5] oligos = { "GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT" };
	Task[7] tasks;
	Thread[7] threads;
	// The longest first, as the C program orders its sections.
	for (int k = 4; k >= 0; k--)
	{
		tasks[2 + k] = { .poly = poly, .length = length, .oligo = oligos[k] };
		threads[2 + k].create(&generate_count, &tasks[2 + k])!!;
	}
	for (int k = 1; k >= 0; k--)
	{
		tasks[k] = { .poly = poly, .length = length, .oligo_length = (sz)k + 1 };
		threads[k].create(&generate_frequencies, &tasks[k])!!;
	}
	for (int k = 0; k < 7; k++)
	{
		(void)threads[k].join();
		io::print((String)tasks[k].out[:tasks[k].out_len]);
	}

	mem::free(poly);
	return 0;
}
