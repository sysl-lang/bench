# Sources

The C, Rust, C++ and Swift programs come from the Computer Language Benchmarks Game source archive
(`https://benchmarksgame-team.pages.debian.net/benchmarksgame/download/benchmarksgame-sourcecode.zip`,
fetched 2026-11-12), the project at https://salsa.debian.org/benchmarksgame-team/benchmarksgame.

**Licence: BSD-3-Clause**, copyright (c) 2004-2008 Brent Fulgham, 2005-2024 Isaac Gouy, as published
in the archive and reproduced in [LICENSE-benchmarksgame.md](LICENSE-benchmarksgame.md). Each file
keeps its own header naming its contributor. `programs/knucleotide/c/khash.h` is
[klib](https://github.com/attractivechaos/klib)'s `khash.h` (MIT licence, Attractive Chaos), which the
k-nucleotide C program includes. The two sysl versions of each program are written for this repo.

"Archive file" below is the file name inside that zip, under the program's directory. **Unchanged**
means the file is copied as it was, apart from the entry in the *Changes* column.

Every program is single-threaded. The reference algorithm column is the work every language, sysl
included, must do (README rule 3).

| program | reference algorithm |
|---|---|
| n-body | the pairwise advance of five bodies, then the energy |
| spectral-norm | ten rounds of A, then A transposed, applied to a vector, with A computed on the fly |
| fannkuch-redux | every permutation in lexicographic order, flipping until a 1 leads |
| binary-trees | every node a separate heap allocation, built, walked and freed |
| mandelbrot | up to 50 iterations per pixel, bits packed eight to a byte |
| fasta | the 139968-state generator, each symbol chosen by scanning the cumulative probabilities |
| k-nucleotide | every k-mer counted into a hash table keyed by its 2k-bit code |
| reverse-complement | each record read whole, complemented through a table, reversed and re-wrapped at 60 |
| regex-redux | headers and newlines removed by a regex, nine alternation patterns counted, five substitutions applied in turn, each by a regular-expression library (see below) |

## Programs

| program | language | archive file | changes |
|---|---|---|---|
| nbody | C | `nbody.gcc-6.gcc` | unchanged |
| nbody | C++ | `nbody.gpp` | unchanged |
| nbody | Rust | `nbody.rust-2.rust` | unchanged |
| nbody | Swift | `nbody.swift-5.swift` | unchanged |
| spectralnorm | C | `spectralnorm.gcc-8.gcc` | unchanged |
| spectralnorm | C++ | `spectralnorm.gpp` | unchanged |
| spectralnorm | Rust | `spectralnorm.rust` | the `parallel` helper and `std::thread` removed; `mult_Av` and `mult_Atv` call `mult` once over the whole slice |
| spectralnorm | Swift | `spectralnorm.swift-8.swift` | unchanged |
| fannkuchredux | C | `fannkuchredux.gcc-3.gcc` | unchanged |
| fannkuchredux | C++ | `fannkuchredux.gpp-3.gpp` | unchanged |
| fannkuchredux | Rust | `fannkuchredux.rust-2.rust` | the four threads replaced by one call of `work` over the whole range |
| fannkuchredux | Swift | `fannkuchredux.swift-8.swift` | unchanged |
| binarytrees | C | `binarytrees.gcc` | `#include <malloc.h>` removed (absent on macOS) |
| binarytrees | C++ | `binarytrees.gpp-2.gpp` | unchanged |
| binarytrees | Rust | `binarytrees.rust` | the `typed_arena` crate (an arena, so not the reference allocation pattern) replaced by `Box` nodes, and the thread per depth by a loop |
| binarytrees | Swift | `binarytrees.swift` | the Dispatch queue replaced by a sequential loop |
| mandelbrot | C | `mandelbrot.gcc-8.gcc` | unchanged |
| mandelbrot | C++ | `mandelbrot.gpp-5.gpp` | unchanged |
| mandelbrot | Rust | `mandelbrot.rust` | `thread::spawn` replaced by calling each worker closure in turn on the main thread |
| mandelbrot | Swift | `mandelbrot.swift-8.swift` | `import Glibc` changed to `import Darwin` |
| fasta | C | `fasta.gcc-2.gcc` | unchanged (linear lookup, its default) |
| fasta | C++ | `fasta.gpp-2.gpp` | unchanged |
| fasta | Rust | `fasta.rust-3.rust` | unchanged |
| fasta | Swift | none | **a port of the C program above, written for this suite**: the archive's Swift programs build a `String` a `Character` at a time (`fasta.swift-8`) or use Dispatch threads (`fasta.swift-2`, `-3`), neither of which is the C program's work |
| knucleotide | C | `knucleotide.gcc` | unchanged; needs `khash.h` |
| knucleotide | C++ | `knucleotide.gpp-3.gpp` | `__gnu_pbds::cc_hash_table` replaced by `std::unordered_map` (libc++ has no pb_ds), and the `std::async` worker per core by one call |
| knucleotide | Rust | `knucleotide.rust` | the archive program keys a `HashMap` by a freshly allocated `Vec<u8>` per position, which is a different data structure from the others' integer keys. Rewritten to key a `HashMap` by the 2k-bit `u64` code with a one-multiply hasher; the reading, sorting and output are the archive's. Threads removed |
| knucleotide | Swift | `knucleotide.swift-2.swift` | `concurrentPerform` over 8 tasks replaced by a loop over one task; the Dispatch queues removed |
| revcomp | C | `revcomp.gcc-4.gcc` | unchanged |
| revcomp | C++ | `revcomp.gcc-4.gcc` | **the C program ported to C++** (casts on `malloc`/`realloc`, the table copied with `memcpy`). The archive's C++ programs (`revcomp.gpp`, `-2`, `-3`) read line by line through iostreams and ran 45 times slower than C, which is the I/O library rather than the algorithm |
| revcomp | Rust | `revcomp.rust-2.rust` | `rayon::join` replaced by a local sequential `join` |
| revcomp | Swift | `revcomp.swift` | the Dispatch reader, worker and writer queues replaced by a sequential loop |

### Go, D and Odin

Go's programs come from the same archive (`*.go` files, BSD-3, headers kept). Where several entries
exist the one chosen is the single-threaded entry that is the C program's algorithm, or the fastest
threaded one converted. Go has no optimisation flags, so `go build` runs with its defaults.

| program | Go archive file | changes |
|---|---|---|
| nbody | `nbody.go` | unchanged |
| spectralnorm | `spectralnorm.go-8.go` | unchanged |
| fannkuchredux | `fannkuchredux.go-8.go` | unchanged |
| binarytrees | `binarytrees.go-7.go` | unchanged (a `*Node` per allocation) |
| mandelbrot | `mandelbrot.go-8.go` | unchanged |
| fasta | `fasta.go-8.go` | unchanged (a transliteration of the C program, linear lookup) |
| knucleotide | `knucleotide.go-4.go` | keys the `map` by the 2k-bit `uint32`/`uint64` code. The `runtime.NumCPU` goroutine workers and result channels replaced by running the seven jobs in order on the main goroutine |
| revcomp | `revcomp.go-2.go` | unchanged |

**D and Odin are not in the archive.** Every D and Odin program is **a port of the C program, written
for this suite** (same algorithm and data layout, idiomatic for the language): `nbody`,
`spectralnorm`, `fannkuchredux`, `binarytrees`, `mandelbrot`, `fasta`, `knucleotide` and `revcomp`, in
both languages, from the same C file as the C row above. k-nucleotide counts into D's built-in
associative array `uint[ulong]` and Odin's built-in `map[u64]u32`, keyed by the 2k-bit code. D uses
`core.stdc` stdio and `malloc` where the C program does; Odin uses `core:bufio` over stdin and stdout
and `new`/`free`.

### Java

Java's programs come from the same archive (`*.java` files, BSD-3, headers kept), compiled with `javac`
and run with `java -cp`. Each is the single-threaded entry that is the C program's algorithm; none needed a
change, and every one is single-threaded as published.

| program | Java archive file | changes |
|---|---|---|
| nbody | `nbody.java-8.java` | unchanged |
| spectralnorm | `spectralnorm.java-8.java` | unchanged |
| fannkuchredux | `fannkuchredux.java-8.java` | unchanged |
| binarytrees | `binarytrees.java-2.java` | unchanged (a `TreeNode` per allocation, no pool) |
| mandelbrot | `mandelbrot.java-8.java` | unchanged |
| fasta | `fasta.java-8.java` | unchanged (a transliteration of the C program, linear lookup) |
| knucleotide | `knucleotide.java-8.java` | unchanged (a `HashMap<String,Integer>` keyed by the k-mer as a string, sorted by count) |
| revcomp | `revcomp.java-4.java` | unchanged |

### C3, Eiffel

**C3 and Eiffel are not in the archive.** Every C3 and Eiffel program is **a port of the C program, written
for this suite**, from the same C file as the C row above (same algorithm and data layout, idiomatic for
the language).

- **C3**: `libc` `putc`, `fwrite` and `fgets` for output and input where the C program uses stdio; `mem::alloc`
  and `mem::free` for the tree nodes. k-nucleotide counts into the standard library's `HashMap{ulong, uint}`
  keyed by the 2k-bit code and sorts with `libc::qsort`. reverse-complement fills a growing buffer in
  order through the complement table and writes it back reversed, where the C program fills from the end.
- **Eiffel** (EiffelStudio's `ec`): arrays are `ARRAY [REAL_64]` and `ARRAY [INTEGER]` (n-body keeps one
  array per field, because a second class for the body would put a second file in the directory);
  binary-trees has a second class `TREE_NODE`; output goes through `io`. k-nucleotide counts into
  `HASH_TABLE [INTEGER, INTEGER_64]` keyed by the 2k-bit code and orders the at most sixteen entries of
  a frequency table with an insertion sort. reverse-complement, like C3's, builds the sequence in order
  and writes it back reversed. Each program has an `.ecf` project file with two targets, `release` and
  `contracts` (README rule 7).

### Ada

**Every Ada program is a port of the C program, written for this suite** (same algorithm and data
layout, idiomatic Ada, one `.adb` file per program), compiled with GNAT 16.1.0. The archive's Ada
programs were passed over, not adapted: the single-threaded ones (`nbody.gnat`, `spectralnorm.gnat`,
`binarytrees.gnat`, `fasta.gnat`, `revcomp.gnat`) are the 2005 originals, each split across several
compilation units that `gnatchop` would have to cut apart, and the fast ones (`fannkuchredux.gnat-3`,
`knucleotide.gnat-2`, `mandelbrot.gnat-3`, `spectralnorm.gnat-3`, `revcomp.gnat-2`) are built on Ada
tasks, so adapting them to one thread means rewriting them. Each file keeps the header of the C
program it ports, so **the licence is the Benchmarks Game's BSD-3-Clause** as for the C programs.

- **Numbers**: `Long_Float` and `Ada.Numerics.Long_Elementary_Functions.Sqrt`; output through
  `Float_IO` with `Aft => 9, Exp => 0` (and `Aft => 3` for k-nucleotide's percentages, which the C
  program divides in single precision, so the Ada divides in `Float`).
- **binarytrees**: an access type, `new` and `Ada.Unchecked_Deallocation` per node (GNAT's default pool
  is `malloc`/`free`).
- **mandelbrot**: a row of bytes at a time written to a `Text_Streams` stream, because `Text_IO` is
  text.
- **fasta, revcomp, knucleotide**: input and output through `Ada.Text_IO` lines; revcomp fills a buffer
  from its end through the complement table, as the C program does.
- **knucleotide** counts into the standard library's `Ada.Containers.Hashed_Maps` (`Unsigned_64` to
  `Unsigned_32`) keyed by the 2k-bit code, with the C program's `key xor key >> 7` hash, and sorts the
  elements with `Ada.Containers.Generic_Array_Sort`.

### regex-redux

regex-redux measures a regular-expression library more than a compiler, and the Benchmarks Game lets
each language pick its library ("Contentious. Different libraries."). The rule here (README rule 3):
**the language's standard regex library, unless the Game's entries for that language use a faster
one, in which case that one, in the form of the Game's fastest entry, made single-threaded.** The
Game's fastest entries all use PCRE2 with its JIT, so most languages here do. Every program reads the
whole input, removes headers and newlines with `>.*\n|\n` (or an equivalent spelling where `.` matches
a newline), counts the nine variants, then applies the five substitutions in turn. The archive's
reference output for its 1000-line input is `expected/ref/regexredux.out` (archive file `1000_out`;
the input, `regexredux-input1000.txt`, is the same file as `knucleotide.in`).

**PCRE2 is Homebrew's** (10.49, built with the JIT). macOS has a `/usr/lib/libpcre2-8` of its own,
built without the JIT; a program that finds that one either fails (`pcre2_jit_compile` answers
`-45`, "bad JIT option") or silently runs PCRE2's interpreter, so every build and loader below names
Homebrew's copy outright.

| language | archive file | library | changes |
|---|---|---|---|
| C, `c-tuned` | `regexredux.gcc-5.gcc` (the Game's fastest C) | PCRE2, JIT | unchanged: the `#pragma omp` lines are ignored without `-fopenmp` (Apple clang has none), so it runs on one thread. `c-tuned` is a copy: nothing faster than PCRE2's JIT is known for C |
| C++ | `regexredux.gpp-6.gpp` (the fastest C++) | PCRE2, JIT | `std::launch::async` changed to `std::launch::deferred`, so each task runs on the main thread when its result is asked for |
| Rust, `rust-tuned` | `regexredux.rust-7.rust` (the Game's fastest program) | PCRE2, JIT | the `pcre2_sys` and `libc` crates replaced by the `extern "C"` declarations they provide (the build is a bare `rustc` with no crates); `rayon::scope`, the `mpsc` channels and `into_par_iter` replaced by sequential calls. `rust-tuned` is a copy. **The entries using the `regex` crate (`regexredux.rust`, `-2` to `-6`) were not used**: the crate cannot be built without cargo, and the PCRE2 entry is the Game's fastest |
| Swift | `regexredux.swift-4.swift` | Foundation `NSRegularExpression` (every Swift entry's) | the `DispatchGroup` and its queues removed; the replacement chain and the counts run in turn |
| Go | `regexredux.go-5.go` (the fastest Go) | PCRE2, JIT, through cgo | the archive program imports `github.com/GRbit/go-pcre`, a cgo binding to the retired PCRE1 (not installed, and a module fetch); it is replaced by a few dozen lines of cgo over PCRE2 making the same calls (`pcre2_jit_compile`, `pcre2_jit_match`). Goroutines and `GOMAXPROCS` removed. Go's own `regexp` (`regexredux.go`, `-3`) is about eight times slower on the Game |
| Java | `regexredux.java-2.java` (the JVM form of the fastest Java, `graalvmaot-4`) | PCRE2, JIT, through `java.lang.foreign` | the jextract-generated `jextract_pcre2.pcre2_h` (not in the archive) replaced by a nested class of hand-written downcalls to the same seven functions; the executor's tasks called in turn. Run as every Java program here, on the JVM, so the time includes startup and JIT warm-up. The JVM warns on stderr that a restricted method was called; it does not affect the output |
| Julia | `regexredux.julia-5.julia` (the fastest Julia) | Base's PCRE2 (Julia ships it, JIT on) | the `Threads.@spawn` around the substitutions and its `wait` removed |
| Nim | none (not in the archive) | standard `std/re`, which is PCRE2 with the JIT | written for this suite. `std/re` opens `libpcre2-8.0.dylib` by name at run time, which finds macOS's JIT-less copy; `regexredux.nim.cfg` beside the source overrides that `dynlib` and links Homebrew's |
| Zig | none | PCRE2, JIT | Zig has no regex library: **a port of the C program** above to Zig, same calls |
| D | none | standard `std.regex`, every pattern compiled to native code at compile time with `ctRegex` | written for this suite |
| Odin | none | standard `core:text/regex` (compiled to its own VM), walked with its match iterator | written for this suite. `.` matches a newline in Odin's regex, so the header pattern is spelled `>[^\n]*\n\|\n` |
| C3 | none | standard `std::encoding::experimental::regex` (POSIX ERE, musl's TNFA matcher) | written for this suite. The header pattern is compiled with `NEWLINE`, so `.` stops at a newline as in Perl |
| Ada | `regexredux.gnat-5.gnat` passed over | GNAT's `GNAT.Regpat` | written for this suite. **The Game's only working Ada entry (`gnat-5`) was not adapted**: it is not a regex program — it hand-translates each pattern into GNAT's SPITBOL pattern combinators (`BreakX`, `Any`, `Break`) — and it is five compilation units built on Ada tasks. `gnat-6` (PCRE, tasks) fails the Game's output check. A newline in the pattern is written `\n`, because `GNAT.Regpat.Compile` refuses a literal one ("junk on end") |
| Eiffel | none | Gobo's `RX_PCRE_REGULAR_EXPRESSION` (a PCRE-syntax matcher written in Eiffel), which ships with EiffelStudio | written for this suite; `regexredux.ecf` adds `$ISE_LIBRARY/library/gobo/gobo_regexp.ecf`. EiffelStudio's own PCRE binding is in its `unstable` tree and was not used. **It does not finish at the timed size**: the substitutions from `<[^>]*>` on hold memory in proportion to the run of text a `[^…]*` crosses (1.87 GB at the 10 MB input with a full collection after every step, 70 MB through the first two), so the 100 MB input is killed for memory after printing the nine counts. It verifies at the small size and its 10 MB output matches C's |

## Implementation variants of one algorithm

Some programs differ in how the same arithmetic is laid out, as they do on the Benchmarks Game. The
Rust spectral-norm and the C++ and Rust mandelbrot carry two values in a struct or eight pixels in an
array so the optimizer can vectorize, and the Rust n-body computes all pairwise differences in arrays.
They do the same operations on the same data as C and are kept; the table's ratios below 1.00 for Rust
and C++ are mostly this. The fannkuch programs generate the permutations in the same order by different
rotation schemes (C: Ledrug's; C++: Branimir Maksimovic's; Rust: a factorial-number scheme; Swift and
sysl: Rex Kerr's count array).

## The two sysl forms

Both sysl forms use C's algorithm: the same work, the same arithmetic on the same data. (regex-redux,
whose work is a library's, is the exception: see its entry below.)

**`sysl-idiomatic`** is what a sysl programmer writes by default: the pleasant form, using whatever the
language offers for writing it pleasantly. That includes vectors (`<N>T`) where they are the natural
tool: mandelbrot computes the eight pixels of one output byte as one `<8>real`.

**`sysl-tuned`** may use any documented feature that trades pleasantness for speed: vectors everywhere,
fixed-size arrays, unchecked indexing, explicit layouts, manual unrolling. It may not carry a
workaround for a compiler gap. The test is whether the change would be pointless once the compiler
does its job; if so, it is an entry in FINDINGS.md and not code. Hand-hoisting fields into locals,
calling `llvm.sqrt` by hand, hand strength reduction and keeping generator state in a local by hand
are all workarounds in this sense. Where no legitimate feature beats the idiomatic program,
`sysl-tuned` is a copy of it.

What each `sysl-tuned` program does differently from `sysl-idiomatic`:

- **nbody**: a body's position and velocity are `<3>real`, so a pair's distance, its squared length
  and both velocity updates are vector operations.
- **spectralnorm**: a copy. Rust's form, two columns per step, needs the integer denominators of two
  columns as a `<2>real`, and sysl has no conversion from `<2>usize` to `<2>real` (FINDINGS.md).
- **fannkuchredux**: a copy. Three `[16]usize` arrays in place of the heap slices measured no faster
  (1.351 s against 1.333 s).
- **binarytrees, mandelbrot, fasta, knucleotide, revcomp**: copies.
- **regexredux**: not the same library. `sysl-idiomatic` uses the standard `sysl.regex` (POSIX ERE,
  a Pike VM; `.` matches a newline there, so the header pattern is `>[^\n]*\n|\n`) and its
  `find_all` and `replace_all`. `sysl-tuned` is C's program: PCRE2 with the JIT, through nine `extern`
  declarations of the PCRE2 functions in the file itself, because the org's `pcre2` package binds
  only the interpreter (`pcre2_match`) and allocates match data on every search. Its build sets
  `LIBRARY_PATH` to Homebrew's PCRE2 so that `@link("pcre2-8")` does not find macOS's JIT-less copy.
