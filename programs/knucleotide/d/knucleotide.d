// The Computer Language Benchmarks Game: k-nucleotide. A port of the C program (Jeremy Zerfas's),
// written for this suite: one pass per oligonucleotide length over the encoded sequence, counting
// 2k-bit keys in a hash table (D's built-in associative array), run sequentially.
import core.stdc.stdio : printf, fgets, stdin;
import core.stdc.string : memcmp, strlen;
import core.stdc.stdlib : malloc, realloc;
import std.algorithm.sorting : sort;

// A=0, C=1, G=2, T=3, for either case.
ubyte codeForNucleotide(char c)
{
    // Indexed by c & 7: 'A' is 1, 'C' is 3, 'T' is 4, 'G' is 7.
    static immutable ubyte[8] table = [0, 0, 0, 1, 3, 0, 0, 2];
    return table[c & 7];
}

struct Element
{
    ulong key;
    uint value;
}

uint[ulong] countAll(const ubyte[] poly, size_t len)
{
    uint[ulong] counts;
    ulong key = 0;
    const ulong mask = (cast(ulong) 1 << (2 * len)) - 1;
    foreach (i; 0 .. len - 1)
        key = ((key << 2) & mask) | poly[i];
    foreach (i; len - 1 .. poly.length)
    {
        key = ((key << 2) & mask) | poly[i];
        if (auto p = key in counts)
            ++*p;
        else
            counts[key] = 1;
    }
    return counts;
}

void frequencies(const ubyte[] poly, size_t len)
{
    auto counts = countAll(poly, len);
    auto elements = new Element[counts.length];
    size_t n = 0;
    foreach (k, v; counts)
        elements[n++] = Element(k, v);

    elements.sort!((a, b) => a.value != b.value ? a.value > b.value : a.key < b.key);

    foreach (e; elements)
    {
        char[32] name;
        ulong key = e.key;
        for (size_t j = len; j > 0;)
        {
            j--;
            name[j] = "ACGT"[key & 3];
            key >>= 2;
        }
        name[len] = 0;
        float pct = 100.0f * e.value / (poly.length - len + 1);
        printf("%s %.3f\n", name.ptr, cast(double) pct);
    }
    printf("\n");
}

void count(const ubyte[] poly, string oligo)
{
    auto counts = countAll(poly, oligo.length);
    ulong key = 0;
    foreach (c; oligo)
        key = (key << 2) | codeForNucleotide(c);
    ulong n = 0;
    if (auto p = key in counts)
        n = *p;
    printf("%llu\t%.*s\n", n, cast(int) oligo.length, oligo.ptr);
}

int main()
{
    char[4096] buffer;

    // Find the start of the third polynucleotide.
    while (fgets(buffer.ptr, buffer.length, stdin) && memcmp(">THREE".ptr, buffer.ptr, 6))
    {
    }

    size_t capacity = 1048576;
    size_t length = 0;
    auto poly = cast(ubyte*) malloc(capacity);

    while (fgets(buffer.ptr, buffer.length, stdin) && buffer[0] != '>')
    {
        for (size_t i = 0; buffer[i] != '\0'; i++)
            if (buffer[i] != '\n')
                poly[length++] = codeForNucleotide(buffer[i]);

        if (capacity - length < buffer.length)
        {
            capacity *= 2;
            poly = cast(ubyte*) realloc(poly, capacity);
        }
    }
    const polynucleotide = poly[0 .. length];

    frequencies(polynucleotide, 1);
    frequencies(polynucleotide, 2);
    count(polynucleotide, "GGT");
    count(polynucleotide, "GGTA");
    count(polynucleotide, "GGTATT");
    count(polynucleotide, "GGTATTTTAATT");
    count(polynucleotide, "GGTATTTTAATTTATAGT");
    return 0;
}
