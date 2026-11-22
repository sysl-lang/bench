# plb2 — Programming Language Benchmark v2, with sysl

[plb2](https://github.com/attractivechaos/plb2) is Heng Li's benchmark of four small programs, each a
few dozen lines of tight code:

| program | what it does | stresses |
|---|---|---|
| nqueen | counts the solutions of 15 queens by backtracking over bit masks | integer and branch code |
| matmul | multiplies two 1500×1500 matrices of doubles, the plain triple loop | floating point, vectorisation |
| sudoku | solves 20 hard puzzles 200 times by exact cover | small arrays, branches |
| bedcov | interval coverage over an implicit interval tree of 1,000,000 intervals | memory, a radix sort, a growable array |

This folder runs it in **C, Rust, Zig, Swift, Nim, D and sysl**. Every program but sysl's is upstream's
own file, unmodified, from commit `1181b3b` (vendored whole in [`upstream/`](upstream/), CC0 1.0;
`src/c/sudoku.c` carries its own MIT licence), built with the flags of upstream's own Makefile for its
language. Upstream has no sysl, so [`written/sysl/`](written/sysl/) holds four ports of upstream's
C, each following the C program's algorithm, data layout and loop order step for step, written as
ordinary sysl. C is the baseline of every ratio.

Not every cell runs, and the report says why for each:

- **Zig**: upstream has only nqueen and matmul, written for Zig 0.11, and neither compiles on Zig
  0.17.1 (`nqueen.zig:5:21: error: binary operator '*' has whitespace on one side, but not the other`;
  `matmul.zig:4:13: error: local variable is never mutated`). They are shown as not building, not
  fixed.
- **Rust bedcov** prints `8195479573` where C and every other language print `8195494005`. It is
  upstream's program and is timed as it stands; the report marks it and leaves it out of Rust's
  geometric mean.
- **D matmul** prints `-143.5` (D's `writeln` gives six significant digits) and **Nim sudoku** leaves
  out the blank line after each puzzle; both are the right answer printed differently.

[METHODOLOGY.md](METHODOLOGY.md) says how it is built, checked and timed. The results are in
[`results/`](results/): `report.md`, `report.html` (self-contained), and hyperfine's raw JSON.

## Reproducing

You need `cc` (clang), `rustc`, `swiftc`, `zig`, `nim`, `ldc2`, `sysl`, `hyperfine` and `python3` on
`PATH` (on macOS: Xcode's command line tools for `cc` and `swiftc`, rustup for `rustc`, and
`brew install zig nim ldc hyperfine sysl-lang/tap/sysl`). Then, on a quiet machine:

```
zsh plb2/reproduce.zsh
```

It builds every program into `plb2/build/` (`scripts/build.zsh`), checks each one's output against
upstream C's (`scripts/verify.py`, against [`expected/`](expected/)), times them
(`scripts/time.zsh`) and writes the report (`scripts/report.py`). `SYSL=/path/to/sysl` picks another
sysl; `PLB2_SEED=<n>` replays an earlier run's order (`results/meta.json` records it);
`BENCH_LANGS="c sysl"` and `BENCH_PROGRAMS=nqueen` narrow a build or a run.
