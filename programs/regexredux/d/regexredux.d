// regex-redux, written for this suite after the Benchmarks Game's programs:
// D's standard std.regex, with every pattern compiled to native code at
// compile time by ctRegex (its fastest form). One thread.

import std.array : join;
import std.meta : AliasSeq;
import std.range : walkLength;
import std.regex : ctRegex, matchAll, replaceAll;
import std.stdio : stdin, writeln;

alias variants = AliasSeq!(
    "agggtaaa|tttaccct",
    "[cgt]gggtaaa|tttaccc[acg]",
    "a[act]ggtaaa|tttacc[agt]t",
    "ag[act]gtaaa|tttac[agt]ct",
    "agg[act]taaa|ttta[agt]cct",
    "aggg[acg]aaa|ttt[cgt]ccct",
    "agggt[cgt]aa|tt[acg]accct",
    "agggta[cgt]a|t[acg]taccct",
    "agggtaa[cgt]|[acg]ttaccct",
);

alias substs = AliasSeq!(
    "tHa[Nt]", "<4>",
    "aND|caN|Ha[DS]|WaS", "<3>",
    "a[NSt]|BY", "<2>",
    "<[^>]*>", "|",
    `\|[^|][^|]*\|`, "-",
);

void main()
{
    auto input = cast(string) stdin.byChunk(1 << 16).join;
    auto sequence = input.replaceAll(ctRegex!(">.*\n|\n"), "");

    static foreach (v; variants)
        writeln(v, " ", sequence.matchAll(ctRegex!v).walkLength);

    auto replaced = sequence;
    static foreach (i; 0 .. substs.length / 2)
        replaced = replaced.replaceAll(ctRegex!(substs[2 * i]), substs[2 * i + 1]);

    writeln();
    writeln(input.length);
    writeln(sequence.length);
    writeln(replaced.length);
}
