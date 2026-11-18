# bench

A cross-language benchmark suite that times [sysl](https://github.com/sysl-lang/sysl) against C, Rust,
C++ and Swift on ten programs from the [Computer Language Benchmarks
Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/): n-body, spectral-norm,
fannkuch-redux, binary-trees, mandelbrot, fasta, k-nucleotide, reverse-complement, regex-redux and pidigits.

Its purpose is to find where sysl's generated code loses to the other compilers. Each slow program is
traced to a cause in [FINDINGS.md](FINDINGS.md).

A second suite, **[Are We Fast Yet](awfy/README.md)** (Marr, Daloze and Mössenböck, DLS 2016), lives
in [`awfy/`](awfy/) with its own scripts and results: fourteen object-oriented benchmarks that every
language writes with the same core language, collections and harness, timed against the suite's own
C++ port (its Java port is not run: rule 9 below).

## What it measures

Each program is written once per language. sysl has two versions:

- **`sysl-idiomatic`** is what a sysl programmer writes by default: the pleasant form, with no type,
  suffix or cast the compiler can infer, standard-library containers, and vectors (`<N>T`) only where
  they are the natural tool, as in mandelbrot. **This is the form that counts.**
- **`sysl-tuned`** may use any documented sysl feature that trades pleasantness for speed: vectors
  everywhere, fixed-size arrays, unchecked indexing, explicit layouts, manual unrolling. It may not
  work around the compiler: a change that would be pointless once the compiler does its job (hoisting
  fields into locals by hand, calling an intrinsic by hand, hand strength reduction) is a finding in
  [FINDINGS.md](FINDINGS.md), not code. Where no such feature beats the idiomatic program, `sysl-tuned`
  is a copy of it.

Both sysl forms use the same algorithm as C.

C and Rust also have a tuned column each, **`c-tuned`** and **`rust-tuned`**, under the same rules as
`sysl-tuned`: single-threaded, the same algorithm (rule 3), but any speed technique the language offers —
NEON intrinsics (`arm_neon.h`, `core::arch::aarch64`), unchecked indexing, fixed arrays, explicit
layouts, manual unrolling, faster I/O. Rust stays std-only. They start from the fastest Benchmarks Game
entries; where no technique beats the plain program, the tuned file is a copy of it. SOURCES.md lists
what each one does. The plain `c` and `rust` columns are unchanged, and C remains the baseline of
every ratio.

The C, Rust, C++ and Swift programs are Benchmarks Game sources (BSD-3). Where the site publishes only
a threaded or crate-dependent program, it is adapted to what the rules below require. [SOURCES.md](SOURCES.md)
names the origin of every file and says exactly what was changed.

## The rules

1. **Single-threaded, in every language.** One core, no thread, task queue or `rayon`.
2. **The idiomatic form counts.** `sysl-tuned` is reported beside it, never instead of it.
3. **Every program does the same work.** The algorithm is fixed per program (SOURCES.md lists it): the
   same generator, the same data structure, the same per-element operation. In particular trees are
   built from individually allocated nodes, k-mers are counted in a hash table, and fasta picks each
   symbol by scanning the cumulative probabilities. A version that changes the algorithm, such as an
   arena for binary-trees or a direct-indexed array for k-nucleotide, is not allowed in either sysl form.
   As in the Benchmarks Game, k-nucleotide's hash table must be the language's built-in or standard
   library one (a custom key type, hasher and capacity hint are allowed); a table the program writes
   itself is not. Fortran has no hash table in the language or its ISO standard library (the
   Benchmarks Game has no Fortran k-nucleotide for that reason), so its program uses the hash map of
   [fortran-lang stdlib](https://stdlib.fortran-lang.org), the community's de facto standard library,
   as the C program uses klib's `khash.h`.
4. **Output is verified before anything is timed.** A wrong answer fails the run.
5. **Release flags**: C and C++ `-O3 -march=native`; Rust `-C opt-level=3 -C target-cpu=native`; Swift
   `-O`; Zig `-O ReleaseFast -mcpu=native`; Odin `-o:speed -microarch:native`;
   C3 `c3c compile -O3` (c3c has no native-CPU option on arm64); Ada (GNAT) `gnatmake -O3 -gnatp -march=native`;
   Fortran `gfortran -O3 -march=native` (IEEE semantics kept, as in C: no `-ffast-math`; gfortran
   rather than LLVM's `flang`, which was slower overall and cannot use the gfortran-built stdlib);
   sysl `--release -O3 --cpu native`.
6. **Checks that remain.** Rust and Odin keep their bounds checks (`rust-tuned` drops them
   where it reads through `get_unchecked` or raw-pointer NEON loads). C, C++, Zig ReleaseFast,
   C3 `-O3` (c3c's unsafe mode, which turns off bounds checks and contracts), Ada `-gnatp`
   (which suppresses every run-time check) and gfortran (which checks array bounds only under
   `-fcheck=bounds`) have none.
7. **Every language compiles ahead of time to a native executable**, and the timing is the whole process.
8. **Swift counts its references (ARC)**, as sysl does: its memory is freed deterministically, when the
   last reference goes, with no collector running beside the program.
9. **No garbage-collected language.** Every language here runs with no garbage collector at run time,
   which is the model sysl competes in. Julia was timed up to 2026-11-16 and Go, Java, D, Eiffel and
   Nim up to 2026-11-17; all were removed on 2026-11-18. Go, Java and Eiffel collect garbage by design;
   D collects by default (its GC-free `-betterC` subset is not how its programs are written); Nim's
   default memory manager, ORC, reference-counts but adds a cycle collector, which is a collector.
   Julia is also a JIT language: a whole-process time is mostly its start-up and compilation, and a
   warm-only measurement is not comparable with the ahead-of-time languages. Swift stays: ARC is
   reference counting with no collector, the same model as sysl (item 8). Earlier results files keep
   the columns of every removed language.

**pidigits and regex-redux are the two programs that lean on a library**, as they do on the
Benchmarks Game. pidigits' work is arbitrary-precision arithmetic. sysl uses its standard library's
big integer (`sysl.math.bigint`); every other language binds
[GMP](https://gmplib.org) 6.3.0 through its own C interop, as the Game's entries do (C, C++, Rust,
Swift, Zig, Odin, C3, Ada, Fortran). Every version runs Mr Ledrug's form of Gibbons'
spigot; SOURCES.md says which library each uses.

regex-redux's work is a regular-expression library's: each language uses its standard one where it
has one and nothing faster is in the Game's entries for it, otherwise the library those entries use.
That is PCRE2 with its JIT for C, C++, Rust, Zig and Fortran; `sysl-idiomatic` uses the standard
`sysl.regex`, and `sysl-tuned` calls PCRE2 with its JIT as C does. SOURCES.md gives each language's
choice and how its Game entry was adapted.

The report gives one geometric mean per language and one over every language.

## Layout

```
programs/<name>/{sysl-idiomatic,sysl-tuned,c,c-tuned,rust,rust-tuned,cpp,swift,zig,odin,c3,ada,fortran}/   one source file per directory
                   (Swift's pidigits adds the module map that makes GMP `import gmp`)
expected/ref/      the Benchmarks Game's published output (and input) at a small size
expected/<name>.sha256   sha256 of the output at the timed size, from the C program
scripts/build.zsh  builds everything into build/ and generates the shared input
scripts/run.zsh    verifies, times, and writes results/<date>.{json,md}
results/           one JSON and one Markdown table per run
```

## Verification

`scripts/run.zsh` checks each program twice. At a small size its output is compared byte for byte with
the file the Benchmarks Game publishes (`expected/ref/`). At the size that is timed, its output hash is
compared with `expected/<name>.sha256`, which is the C program's output; the Benchmarks Game publishes
no output at those sizes. The hashes were then confirmed identical across all six implementations.
k-nucleotide, reverse-complement and regex-redux read a fasta file generated by the C `fasta`
at `build/inputs/`.

## Running it

Requires clang, rustc, swiftc, zig, odin, c3c, GNAT (`gnatmake`), gfortran with [fortran-stdlib](https://stdlib.fortran-lang.org) (`brew install fortran-stdlib`, found through `pkg-config`), [hyperfine](https://github.com/sharkdp/hyperfine) 2.x and `sysl` on
`PATH`, and Homebrew's `pcre2` and `boost` (regex-redux).

```
zsh scripts/build.zsh
zsh scripts/run.zsh --verify
zsh scripts/run.zsh
```

`run.zsh` verifies, then runs `hyperfine --warmup 3 --runs 10` for every program and writes
`results/<date>.json` and `results/<date>.md`. The table gives each language's time as a ratio to C
(wall clock, and again from CPU time), the load average at the start and end, and the version of every
toolchain with its LLVM version.

Timings are only meaningful on an idle machine. On the author's machine, where marshal manages the
jobs, the proper way to run it is:

```
caffeinate -dimsu marshal run --exclusive --quiet-load auto --deadline 2h --dir <repo> --label "bench timing" -- zsh scripts/run.zsh
```

A run taken while other builds are going says so in its results file.

**Comparing two sysl compilers.** With `SYSL_DEV=<sysl binary>` and `SYSL_DEV_LIB=<its library/
directory>` in the environment of both `build.zsh` and `run.zsh`, every program's `sysl-idiomatic` and
`sysl-tuned` sources are also built with that compiler, as the columns `sysl-idiomatic-dev` and
`sysl-tuned-dev`, and the report adds a table of the two compilers side by side (`SYSL_DEV_COMMIT`
names its commit in the toolchain list). Every sysl build sets `SYSL_NO_CACHE=1`, so neither
compiler replays a cached build.
