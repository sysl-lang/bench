# bench

A cross-language benchmark suite that times [sysl](https://github.com/sysl-lang/sysl) against C, Rust,
C++, Swift and Go on ten programs from the [Computer Language Benchmarks
Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/): n-body, spectral-norm,
fannkuch-redux, binary-trees, mandelbrot, fasta, k-nucleotide, reverse-complement, regex-redux and pidigits.

Its purpose is to find where sysl's generated code loses to the other compilers. Each slow program is
traced to a cause in [FINDINGS.md](FINDINGS.md).

A second suite, **[Are We Fast Yet](awfy/README.md)** (Marr, Daloze and Mössenböck, DLS 2016), lives
in [`awfy/`](awfy/) with its own scripts and results: fourteen object-oriented benchmarks that every
language writes with the same core language, collections and harness, timed against the suite's own
C++ port (its Java port is not run: rule 9 below).

A third, **[plb2](plb2/README.md)** (Heng Li's Programming Language Benchmark v2), lives in
[`plb2/`](plb2/): four small programs (nqueen, matmul, sudoku, bedcov) run as upstream's own C, Rust,
Zig, Swift, Nim and D, unmodified, beside sysl ports of upstream's C.

## What it measures

Each program is written once per language. sysl has two versions:

- **`sysl-idiomatic`** is what a sysl programmer writes by default: the pleasant form, with no type,
  suffix or cast the compiler can infer, standard-library containers, and vectors (`<N>T`) only where
  they are the natural tool, as in mandelbrot. **This is the form that counts.**
- **`sysl-tuned`** may use any documented sysl feature that trades pleasantness for speed: vectors
  everywhere, fixed-size arrays, unchecked indexing, explicit layouts, manual unrolling, and, as
  `c-tuned` and `rust-tuned` may, whatever a program can do itself to get past a compiler or library
  gap (generator state kept in a local, C's own `malloc`ed node, input read with `read(2)`). Each such
  workaround is a "Tuned" line in [FINDINGS.md](FINDINGS.md) naming the compiler or library item that
  would make it pointless, so the gap between the two sysl columns is that list. Where nothing beats
  the idiomatic program, `sysl-tuned` is a copy of it.

Both sysl forms use the same algorithm as C.

C and Rust also have a tuned column each, **`c-tuned`** and **`rust-tuned`**, under the same rules as
`sysl-tuned`: single-threaded, the same algorithm (rule 3), but any speed technique the language offers —
NEON intrinsics (`arm_neon.h`, `core::arch::aarch64`), unchecked indexing, fixed arrays, explicit
layouts, manual unrolling, faster I/O. Rust stays std-only. They start from the fastest Benchmarks Game
entries; where no technique beats the plain program, the tuned file is a copy of it. SOURCES.md lists
what each one does. The plain `c` and `rust` columns are unchanged, and C remains the baseline of
every ratio.

The C, Rust, C++, Swift and Go programs are Benchmarks Game sources (BSD-3). Where the site publishes only
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
5. **Release flags**: C and C++ `-O3 -mcpu=native` (on arm64 Apple clang reads `-march=native` as the
   apple-m1 processor and its features, `-mcpu=native` as this machine's, which is what sysl's
   `--cpu native` and Rust's `target-cpu=native` name); Rust `-C opt-level=3 -C target-cpu=native
   -C codegen-units=1` (the Benchmarks Game's Rust flags); Swift
   `-O` (no processor option, so generic arm64); Zig `-O ReleaseFast -mcpu=native -fsingle-threaded`
   (which also drops the locking in Zig's own standard library); Odin `-o:speed -microarch:native`;
   C3 `c3c compile -O3` (c3c has no native-CPU option on arm64, so generic arm64); Ada (GNAT)
   `gnatmake -O3 -gnatp -march=native` (GCC's spelling: this machine's features, GCC's generic tuning);
   Fortran `gfortran -O3 -march=native` (IEEE semantics kept, as in C: no `-ffast-math`; gfortran
   rather than LLVM's `flang`, which was slower overall and cannot use the gfortran-built stdlib);
   Go `GOARM64=v8.7 go build` (Go has no optimisation level; the Benchmarks Game runs plain `go build`
   with `GOAMD64=v2`, and v8.7 is this machine's architecture level, as clang's `-mcpu=native` reads
   it; no `-gcflags`, so no `-B`);
   sysl `--release -O3 --cpu native`.
6. **Checks that remain.** `sysl-idiomatic` keeps every bounds check, and integer overflow wraps in a
   release build; `sysl-tuned` drops the bounds checks inside its `@unchecked` blocks. Rust and Odin
   keep their bounds checks (`rust-tuned` drops them
   where it reads through `get_unchecked` or raw-pointer NEON loads). Swift `-O` keeps its bounds
   checks and also traps on integer overflow (the Benchmarks Game builds Swift `-Ounchecked`; here it
   keeps its checks, as Rust and sysl do). Go keeps its bounds checks (none of its programs uses
   `-gcflags=-B`) and integer overflow wraps. C, C++, Zig ReleaseFast,
   C3 `-O3` (c3c's unsafe mode, which turns off bounds checks and contracts), Ada `-gnatp`
   (which suppresses every run-time check) and gfortran (which checks array bounds only under
   `-fcheck=bounds`) have none.
7. **Every language compiles ahead of time to a native executable**, and the timing is the whole process.
8. **Swift counts its references (ARC)**, as sysl does: its memory is freed deterministically, when the
   last reference goes, with no collector running beside the program.
9. **One garbage-collected language: Go.** Every other language here runs with no garbage collector
   at run time, which is the model sysl competes in. Go collects garbage by design; it is here because
   it is the language readers compare a new systems language with, so its column says where sysl
   stands against it. Go is held to the rules every other language is: its programs are the Game's
   fastest Go entries made single-threaded (SOURCES.md), and it runs with **`GOMAXPROCS=1`**, so Go
   code runs on one processor as every other program runs on one thread. The collector's mark work
   shares that one processor; the runtime's few service threads still exist, and their CPU time is in
   the CPU-time table. `GOGC` is left at its default, 100, which trades memory for speed: peak RSS is
   in the JSON. Go 1.27 from Homebrew (the report prints the exact version). Julia was timed up to
   2026-11-16 and Go, Java, D, Eiffel and Nim up to 2026-11-17; all were removed on 2026-11-18 and Go
   alone restored on 2026-11-20 (AUDIT.md, "Go"). Java and Eiffel collect garbage by design; D
   collects by default (its GC-free `-betterC` subset is not how its programs are written); Nim's
   default memory manager, ORC, reference-counts but adds a cycle collector, which is a collector.
   Julia is also a JIT language: a whole-process time is mostly its start-up and compilation, and a
   warm-only measurement is not comparable with the ahead-of-time languages. Swift stays: ARC is
   reference counting with no collector, the same model as sysl (item 8). Earlier results files keep
   the columns of every removed language.

**pidigits and regex-redux are the two programs that lean on a library**, as they do on the
Benchmarks Game. pidigits' work is arbitrary-precision arithmetic. sysl uses its standard library's
big integer (`sysl.math.bigint`); every other language binds
[GMP](https://gmplib.org) 6.3.0 through its own C interop, as the Game's entries do (C, C++, Rust,
Swift, Zig, Odin, C3, Ada, Fortran, and Go through cgo, as its fastest Game entry does). Every version runs Mr Ledrug's form of Gibbons'
spigot; SOURCES.md says which library each uses.

regex-redux's work is a regular-expression library's: each language uses its standard one where it
has one and nothing faster is in the Game's entries for it, otherwise the library those entries use.
That is PCRE2 with its JIT for C, C++, Rust, Zig, Fortran and Go (through cgo, as its fastest Game
entry does; Go's own `regexp` is about eight times slower there); `sysl-idiomatic` uses the standard
`sysl.regex`, and `sysl-tuned` calls PCRE2 with its JIT as C does. SOURCES.md gives each language's
choice and how its Game entry was adapted.

The report gives one geometric mean per language and one over every language, and a table of **each
language at its best**: its faster column on each program (the tuned one where it has one) as a ratio
to the faster of `c` and `c-tuned`. **That table is the one to quote.** Every other table divides by
the plain C program, which is weak on the programs listed below and so flatters every language that
beats it (AUDIT.md A6).

## Known weaknesses of the plain columns

The plain columns are the Benchmarks Game's programs, adapted only as SOURCES.md says, paired with
`sysl-idiomatic` and kept as they are because their gaps to sysl drive FINDINGS.md. They are not each
language's best, and these are known to be well below it, single-threaded, on this machine:

| program | column | what it is |
|---|---|---|
| mandelbrot | `c` | `mandelbrot.gcc-8`, one pixel at a time in scalar code; `sysl-idiomatic` computes eight pixels as one `<8>real`, so it runs about 3x faster than this C, and `c-tuned` (NEON) is the C to compare with |
| nbody | `c` | the Game's plain C; the identical algorithm runs in 0.91–0.99 of its time as C3, Ada and Swift ports and in 0.54 of it as `sysl-idiomatic` on sysl dev (FINDINGS, "Where dev stands"), so a ratio to it is not a ratio to C at its best |
| spectralnorm | `c` | `spectralnorm.gcc-8`, one column per step; Rust's two-column form is about 2.6x faster |
| fannkuchredux | `c` | `fannkuchredux.gcc-3`, scalar flips |
| revcomp | `c` | `revcomp.gcc-4`, line-at-a-time `fgets` |
| fasta | `rust` | `fasta.rust-3`, about 1.9x C |
| knucleotide | `rust` | rewritten for this suite from the archive's `Vec<u8>`-keyed program (SOURCES.md); not a Game entry |
| knucleotide | `cpp` | `std::unordered_map` (libc++), because rule 3 asks for the standard library's table and libc++ has no `__gnu_pbds` |
| knucleotide | `swift` | `Dictionary`, whose hash is always SipHash through `Hasher`, as Swift's standard library requires |
| binarytrees | `swift` | a class node with ARC's atomic counts on every retain and release |

**Only C, Rust and sysl have tuned columns.** C++, Swift, Go, Zig, Odin, C3, Ada and Fortran are each
their plain program (Go's are its fastest Game entries, so its column is the nearest to a language at
its best among them), and their ratios are those of the published or ported program, not of the
language at its best.

## Methodology, and what a reader should know

- **One machine.** Apple Silicon (the report names the processor, model, core counts, memory, macOS
  build and power source), arm64 only. The tuned C and Rust columns use NEON intrinsics and build on
  arm64 only.
- **Single-threaded.** No program starts a thread: the C and Fortran programs' OpenMP directives are
  inert (no `-fopenmp`), and every threaded Rust, C++, Swift and Go program was made sequential
  (SOURCES.md). Go runs with `GOMAXPROCS=1` (`scripts/lib.zsh`).
- **Go, the one garbage-collected language** (rule 9): Go 1.27 from Homebrew, `GOARM64=v8.7 go
  build`, `GOMAXPROCS=1`, default `GOGC`. Its time includes the collector's work and its peak RSS the
  heap headroom `GOGC=100` leaves; its binary-trees recycles nodes through `sync.Pool`, Go's explicit
  free list, as the Game's fastest single-threaded Go entry does (AUDIT.md G3). pidigits and
  regex-redux reach GMP and PCRE2 through cgo, so each call pays cgo's crossing.
- **Sizes.** nbody 50,000,000, spectralnorm 5,500, fasta 25,000,000, reverse-complement on fasta
  25,000,000 and pidigits 10,000 are the Game's sizes. binarytrees 18 (Game 21), fannkuchredux 11
  (12), mandelbrot 6,000 (16,000), and k-nucleotide and regex-redux on fasta 10,000,000 (Game
  25,000,000 and 5,000,000) are smaller, to keep a full run near an hour. Every language runs the same
  size.
- **The timing is the whole process** (rule 7): `hyperfine -N --warmup 3 --runs 10`, no shell, output to
  `/dev/null`, input from the generated file, which the warm-ups leave in the page cache for every
  language alike. A process's start-up (3 to 4 ms for `/usr/bin/true` here) is in every time; the
  shortest programs run a few hundred milliseconds or more, so it stays a small share.
- **Order.** hyperfine runs every run of one language, then the next, in the fixed order of
  `scripts/lib.zsh`; there is no interleaving, so a slow drift of the machine's state lands on the
  later columns. The spread table (standard deviation as a percentage of the mean) is the noise a
  difference must beat.
- **Raw data.** Each results JSON keeps every run's wall, CPU, user and system time, peak resident
  set and exit code, beside the mean, standard deviation, minimum and median.
- **Versions.** The report records each toolchain's version when it is written; build and timing
  belong in one session with no toolchain upgraded between them.
- **Verification** compares the output at the small size with the Game's own file and at the timed
  size with the C program's hash, which every language's output matches. It checks output only; a
  program that ends with a non-zero status fails the timing instead, since hyperfine stops on one.
- **pidigits** measures `sysl.math.bigint` against GMP in every other language; **regex-redux**
  measures each language's regular-expression library (above).
- **The tuned binarytrees** in C and Rust check and free each tree in one walk; `sysl-tuned` walks
  twice, as the plain programs do. The difference is against sysl.

## Layout

```
programs/<name>/{sysl-idiomatic,sysl-tuned,c,c-tuned,rust,rust-tuned,cpp,swift,zig,odin,c3,ada,fortran,go}/   one source file per directory
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
no output at those sizes. Every language's output matches it, which `run.zsh --verify` checks on every
run. k-nucleotide and regex-redux read the C `fasta`'s output at 10,000,000, and reverse-complement
its output at 25,000,000, both generated into `build/inputs/` by `build.zsh`.

## Running it

Requires clang, rustc, swiftc, go, zig, odin, c3c, GNAT (`gnatmake`), gfortran with [fortran-stdlib](https://stdlib.fortran-lang.org) (`brew install fortran-stdlib`, found through `pkg-config`), [hyperfine](https://github.com/sharkdp/hyperfine) 2.x and `sysl` on
`PATH`, and Homebrew's `pcre2` and `boost` (regex-redux).

```
zsh scripts/build.zsh
zsh scripts/run.zsh --verify
zsh scripts/run.zsh
```

`run.zsh` verifies, then runs `hyperfine -N --warmup 3 --runs 10` for every program and writes
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
