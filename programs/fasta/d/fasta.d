// The Computer Language Benchmarks Game: fasta. A port of the C program (Drake Diedrich's),
// written for this suite: the 139968-state generator, each symbol chosen by a linear scan of the
// cumulative probabilities, output through stdio.
import core.stdc.stdio : printf, fwrite, putchar, stdout;
import core.stdc.stdlib : atoi, malloc, free;
import core.stdc.string : memcpy, strlen;

enum uint IM = 139968;
enum uint IA = 3877;
enum uint IC = 29573;
enum uint SEED = 42;
enum int LINELEN = 60;

__gshared uint seed = SEED;

double fastaRand(double max)
{
    seed = (seed * IA + IC) % IM;
    return max * seed / IM;
}

immutable string alu =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
    ~ "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
    ~ "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
    ~ "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
    ~ "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
    ~ "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
    ~ "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

immutable string iub = "acgtBDHKMNRSVWY";
immutable double[15] iubP = [
    0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02
];

immutable string homosapiens = "acgt";
immutable double[4] homosapiensP = [
    0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008
];

void repeatFasta(string seq, int n)
{
    int len = cast(int) seq.length;
    char* buffer = cast(char*) malloc(len + LINELEN);
    memcpy(buffer, seq.ptr, len);
    memcpy(buffer + len, seq.ptr, LINELEN);

    int t = 0;
    int wholeLines = n / LINELEN;
    foreach (_; 0 .. wholeLines)
    {
        size_t wrote = fwrite(&buffer[t % len], 1, LINELEN, stdout);
        putchar('\n');
        t += cast(int) wrote;
    }
    fwrite(&buffer[t % len], 1, n - t, stdout);
    free(buffer);
    if (n % LINELEN != 0)
        putchar('\n');
}

int linearLookup(const double[] p, double v)
{
    int i = 0;
    foreach (j; 0 .. p.length - 1)
        if (v > p[j])
            i++;
    return i;
}

void randomFasta(string symb, const double[] probability, int n)
{
    int len = cast(int) symb.length;
    auto p = new double[len];
    char[LINELEN + 2] buffer;
    buffer[LINELEN] = '\n';

    p[0] = probability[0];
    foreach (i; 1 .. len)
        p[i] = probability[i] + p[i - 1];

    int i;
    for (i = 0; i < n / LINELEN; i++)
    {
        foreach (k; 0 .. LINELEN)
        {
            double v = fastaRand(1.0);
            buffer[k] = symb[linearLookup(p, v)];
        }
        fwrite(buffer.ptr, 1, LINELEN + 1, stdout);
    }
    int remainder = n - (i * LINELEN);
    foreach (k; 0 .. remainder)
    {
        double v = fastaRand(1.0);
        buffer[k] = symb[linearLookup(p, v)];
    }
    fwrite(buffer.ptr, 1, remainder, stdout);
    if (n % LINELEN != 0)
        putchar('\n');
}

int main(string[] args)
{
    int n = 1000;
    if (args.length > 1)
        n = atoi(args[1].ptr);

    printf(">ONE Homo sapiens alu\n");
    repeatFasta(alu, n * 2);

    printf(">TWO IUB ambiguity codes\n");
    randomFasta(iub, iubP[], n * 3);

    printf(">THREE Homo sapiens frequency\n");
    randomFasta(homosapiens, homosapiensP[], n * 5);

    return 0;
}
