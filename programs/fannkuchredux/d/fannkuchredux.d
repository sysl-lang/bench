// The Computer Language Benchmarks Game: fannkuch-redux. A port of the C program (Ledrug Katz's),
// written for this suite: Tompkin-Paige iterative permutation generation, flipping until a 1 leads.
import core.stdc.stdio : printf, fprintf, stderr;
import core.stdc.stdlib : atoi, exit;

__gshared int[16] s, t;
__gshared int maxFlips = 0;
__gshared int maxN;
__gshared int odd = 0;
__gshared int checksum = 0;

int flip()
{
    foreach (i; 0 .. maxN)
        t[i] = s[i];
    int i = 1;
    do
    {
        int x = 0, y = t[0];
        while (x < y)
        {
            int c = t[x];
            t[x++] = t[y];
            t[y--] = c;
        }
        i++;
    }
    while (t[t[0]]);
    return i;
}

void rotate(int n)
{
    int c = s[0];
    foreach (i; 1 .. n + 1)
        s[i - 1] = s[i];
    s[n] = c;
}

// Tompkin-Paige iterative perm generation
void tk(int n)
{
    int i = 0;
    int[16] c = 0;

    while (i < n)
    {
        rotate(i);
        if (c[i] >= i)
        {
            c[i++] = 0;
            continue;
        }

        c[i]++;
        i = 1;
        odd = ~odd;
        if (s[0])
        {
            int f = s[s[0]] ? flip() : 1;
            if (f > maxFlips)
                maxFlips = f;
            checksum += odd ? -f : f;
        }
    }
}

int main(string[] args)
{
    if (args.length < 2)
    {
        fprintf(stderr, "usage: %s number\n", args[0].ptr);
        exit(1);
    }

    maxN = atoi(args[1].ptr);
    if (maxN < 3 || maxN > 15)
    {
        fprintf(stderr, "range: must be 3 <= n <= 12\n");
        exit(1);
    }

    foreach (i; 0 .. maxN)
        s[i] = i;
    tk(maxN);

    printf("%d\nPfannkuchen(%d) = %d\n", checksum, maxN, maxFlips);
    return 0;
}
