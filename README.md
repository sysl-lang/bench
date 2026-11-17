# bench

A cross-language benchmark suite that times [sysl](https://github.com/sysl-lang/sysl) against C, Rust,
C++ and Swift on eight programs from the [Computer Language Benchmarks
Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/): n-body, spectral-norm,
fannkuch-redux, binary-trees, mandelbrot, fasta, k-nucleotide and reverse-complement.

Its purpose is to find where sysl's generated code loses to the other compilers. Each slow program is
traced to a cause in [FINDINGS.md](FINDINGS.md).

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
   `-O`; Zig `-O ReleaseFast -mcpu=native`; Nim `-d:danger --opt:speed`; Go `go build` with default flags
   (Go has no optimisation level); D (LDC) `-O3 -release -mcpu=native`; Odin `-o:speed -microarch:native`;
   C3 `c3c compile -O3` (c3c has no native-CPU option on arm64); Ada (GNAT) `gnatmake -O3 -gnatp -march=native`;
   Fortran `gfortran -O3 -march=native` (IEEE semantics kept, as in C: no `-ffast-math`; gfortran
   rather than LLVM's `flang`, which was slower overall and cannot use the gfortran-built stdlib); Java `javac` and `java` with default
   flags (the JIT already targets the host CPU); Eiffel `ec -finalize -c_compile` (EiffelStudio's
   optimised build with Eiffel-level inlining on, `inlining_size` 100, set in each .ecf; without it
   every `ARRAY.item` is an out-of-line call with GC bookkeeping; no native-CPU option); sysl `--release -O3 --cpu native`.
6. **Checks that remain.** Rust, Go, Odin and Java keep their bounds checks. C, C++, Zig ReleaseFast, Nim
   `danger`, C3 `-O3` (c3c's unsafe mode, which turns off bounds checks and contracts), Ada `-gnatp`
   (which suppresses every run-time check) and gfortran (which checks array bounds only under
   `-fcheck=bounds`) have none, and D
   with `-release` drops the bounds checks of `@system` code, which is what these D programs are. Eiffel's
   array indices are checked by a precondition, so they are checked only where assertions are on.
7. **Eiffel is timed twice.** `eiffel` is the finalized build with every assertion off, which is its release
   mode; `eiffel-contracts` is the same source built with `precondition`, `postcondition`, `check`,
   `invariant` and `loop` assertions all on. Each Eiffel program carries its contracts: preconditions on
   index ranges and sizes, class invariants, and loop invariants and variants where the loop has one. The
   second column measures what the contracts cost at run time.
8. **Java's timing is the whole process**, JVM startup and JIT warm-up included, as in the Benchmarks Game:
   `build/<program>/java` is a launcher script that runs `java -cp` on the compiled classes, as the Julia
   one does. Eiffel and C3 compile to native executables.

## Groups

The tables group the languages. **Systems**: c, cpp, rust, zig, d, odin, c3, ada, fortran, nim, swift, sysl-idiomatic,
sysl-tuned. **Managed**: go, java, eiffel, eiffel-contracts, julia. The criterion: a systems language can run with no tracing GC and no
required runtime, with deterministic destruction and control over layout (Swift via Embedded Swift, Nim
via `--os:standalone`, D via `-betterC`); every program here runs in the language's normal hosted mode.
The report gives the geometric mean of each group as well as overall.

## Layout

```
programs/<name>/{sysl-idiomatic,sysl-tuned,c,rust,cpp,swift,zig,nim,julia,go,d,odin,c3,ada,fortran,java,eiffel}/   one source file per directory
                   (Eiffel adds its .ecf project file, and a second class file where a program needs one;
                   `eiffel-contracts` is built from the `eiffel` directory)
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
k-nucleotide and reverse-complement read a fasta file generated by the C `fasta`
at `build/inputs/`.

## Running it

Requires clang, rustc, swiftc, zig, nim, julia, go, ldc2, odin, c3c, GNAT (`gnatmake`), gfortran with [fortran-stdlib](https://stdlib.fortran-lang.org) (`brew install fortran-stdlib`, found through `pkg-config`), a JDK (`javac`, `java`), EiffelStudio (`ec`), [hyperfine](https://github.com/sharkdp/hyperfine) 2.x and `sysl` on
`PATH`.

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
