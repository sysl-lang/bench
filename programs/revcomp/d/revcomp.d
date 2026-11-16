// The Computer Language Benchmarks Game: reverse-complement. A port of the C program (Bob W's),
// written for this suite: each record is read a line at a time, complemented through a 256-entry
// table into the end of a buffer (so it is already reversed), then re-wrapped at 60 columns.
import core.stdc.stdio : fgets, fputs, fwrite, stdin, stdout;
import core.stdc.stdlib : malloc, realloc;
import core.stdc.string : memmove;

enum size_t JBFSIZE = 82;
enum size_t QBFSIZE = 5200;

ubyte[256] makeTable()
{
    ubyte[256] t;
    // The letter pairs of the C program's table, for both cases.
    immutable string from = "ACGTMRWSYKVHDBN";
    immutable string to = "TGCAKYWSRMBDHVN";
    foreach (i; 0 .. from.length)
    {
        t[from[i]] = cast(ubyte) to[i];
        t[from[i] + 32] = cast(ubyte) to[i];
    }
    return t;
}

immutable ubyte[256] xtab = makeTable();

int main()
{
    char[JBFSIZE] jjj;
    char* qqq = cast(char*) malloc(QBFSIZE);
    char* pqstop = qqq + QBFSIZE;
    char* pj = fgets(jjj.ptr, cast(int) JBFSIZE, stdin);
    if (!pj || jjj[0] != '>')
        return 1;

    while (pj)
    {
        fputs(jjj.ptr, stdout);

        char* pq = qqq + 1;
        char* pr = pqstop;
        for (;; pq++)
        {
            pj = fgets(jjj.ptr, cast(int) JBFSIZE, stdin);
            if (!pj || jjj[0] == '>')
                break;
            if (pr <= pq + 61)
            {
                char* newstop = pqstop + 12777888;
                char* newptr = cast(char*) realloc(qqq, newstop - qqq);
                if (newptr != qqq)
                {
                    size_t x = newptr - qqq;
                    pq += x;
                    pr += x;
                    qqq += x;
                    newstop += x;
                    pqstop += x;
                }
                pr = cast(char*) memmove(newstop - (pqstop - pr), pr, pqstop - pr);
                pqstop = newstop;
            }
            while (*pj)
            {
                char c = xtab[cast(ubyte) *pj++];
                if (c)
                    *(--pr) = c;
            }
        }

        for (pq = qqq; pr < pqstop;)
        {
            size_t x = (pqstop - pr) < 60 ? pqstop - pr : 60;
            memmove(pq, pr, x);
            pr += x;
            pq += x;
            *(pq++) = 0xA;
        }
        fwrite(qqq, 1, pq - qqq, stdout);
    }
    return 0;
}
