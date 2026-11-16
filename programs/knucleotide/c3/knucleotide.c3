// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Jeremy Zerfas) to C3, counting into
// the standard library's HashMap keyed by the 2k-bit code of each oligonucleotide.
module knucleotide;
import std::io;
import std::collections::map;
import libc;

alias OligoMap = HashMap{ulong, uint};

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
		uint* count = table.get_or_create_ref(key);
		*count += 1;
	}
}

fn void generate_frequencies(char* poly, sz length, sz oligo_length)
{
	OligoMap table;
	table.init(mem);

	count_oligonucleotides(&table, poly, length, oligo_length);

	sz size = table.len();
	Element* elements = mem::alloc_array(Element, (usz)size);
	sz n = 0;
	table.@each(; ulong key, uint value)
	{
		elements[n++] = { key, value };
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
		io::printfn("%s %.3f", name, 100.0f * (float)elements[i].value / (float)(length - oligo_length + 1));
	}
	mem::free(elements);
	io::printn();
}

fn void generate_count(char* poly, sz length, String oligo)
{
	sz oligo_length = (sz)oligo.len;
	OligoMap table;
	table.init(mem);

	count_oligonucleotides(&table, poly, length, oligo_length);

	ulong key = 0;
	for (sz i = 0; i < oligo_length; i++) key = (key << 2) | code_for_nucleotide(oligo[i]);

	uint count = 0;
	if (try found = table.get(key)) count = found;
	io::printfn("%d\t%s", count, oligo);
	table.free();
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

	generate_frequencies(poly, length, 1);
	generate_frequencies(poly, length, 2);
	generate_count(poly, length, "GGT");
	generate_count(poly, length, "GGTA");
	generate_count(poly, length, "GGTATT");
	generate_count(poly, length, "GGTATTTTAATT");
	generate_count(poly, length, "GGTATTTTAATTTATAGT");

	mem::free(poly);
	return 0;
}
