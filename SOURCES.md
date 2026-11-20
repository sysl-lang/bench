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
| pidigits | Mr Ledrug's form of Gibbons' unbounded spigot: per term `acc = (acc + 2num)(2k+1)`, `den *= 2k+1`, `num *= k`; a digit when `(3num + acc)/den` and `(4num + acc)/den` agree, then `acc = 10(acc - d·den)`, `num *= 10` |

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
| knucleotide | C++ | `knucleotide.gpp-3.gpp` | `__gnu_pbds::cc_hash_table` replaced by `std::unordered_map` (libc++ has no pb_ds), and the `std::async` worker per core by one call. Each k-mer's code is rolled from the previous one, as every other program does (rule 3), where the archive re-encoded all k bases at every position (AUDIT.md A4) |
| knucleotide | Rust | `knucleotide.rust` | the archive program keys a `HashMap` by a freshly allocated `Vec<u8>` per position, which is a different data structure from the others' integer keys. Rewritten to key a `HashMap` by the 2k-bit `u64` code with a one-multiply hasher; the reading, sorting and output are the archive's. Threads removed |
| knucleotide | Swift | `knucleotide.swift-2.swift` | `concurrentPerform` over 8 tasks replaced by a loop over one task, whose table is the result (merging it into an empty table, as the threaded original must, inserted every key twice: AUDIT.md A3); the Dispatch queues removed |
| revcomp | C | `revcomp.gcc-4.gcc` | unchanged |
| revcomp | C++ | `revcomp.gcc-4.gcc` | **the C program ported to C++** (casts on `malloc`/`realloc`, the table copied with `memcpy`). The archive's C++ programs (`revcomp.gpp`, `-2`, `-3`) read line by line through iostreams and ran 45 times slower than C, which is the I/O library rather than the algorithm |
| revcomp | Rust | `revcomp.rust-2.rust` | `rayon::join` replaced by a local sequential `join` |
| revcomp | Swift | `revcomp.swift` | the Dispatch reader, worker and writer queues replaced by a sequential loop |

### Go, D and Odin

Go's programs come from the same archive (`*.go` files, BSD-3, headers kept), **each the Game's
fastest Go entry for the program by elapsed time that builds and runs on this machine exactly as
published**: no line of any file is changed, so the programs are multi-threaded, as the Game runs
them, and Go uses every core (no `GOMAXPROCS` is set; AUDIT.md G1). The Game's published list for
each program (`performance/<program>.html`, fetched 2026-11-20) was walked from the fastest down;
entries passed over are in the table below. "Game" columns are the Game's published Go
measurements, elapsed and CPU seconds, on its 4-core x86; `-N` is the archive file
`<program>.go-N.go` (`-1` is `<program>.go`). Build: `GOARM64=v8.7 go build` (README rule 5, AUDIT.md
G2), with cgo's library paths for GMP and Homebrew's PCRE1 (named below) the only other additions.
Every program is checked at the Game's own size against the Game's published output (AUDIT.md Go).

| program | Go archive file | Game elapsed / CPU (s) | passed over (fastest first) |
|---|---|---|---|
| nbody | `nbody.go-3.go` | 6.62 / 6.62 | none |
| spectralnorm | `spectralnorm.go-4.go` | 1.46 / 5.72 | none |
| fannkuchredux | `fannkuchredux.go-3.go` | 8.91 / 35.03 | none |
| binarytrees | `binarytrees.go-2.go` | 14.36 / 14.94 | none |
| mandelbrot | `mandelbrot.go-2.go` | 6.87 / 27.30 | `-4` (3.78) and `-1` (5.04): both compute each coordinate as `x*(2/size)`, which rounds some boundary pixels the other way from the Game's reference; on this machine their output is wrong at 200 (the Game's own output file) and at 6,000. Both build and run; the output is not the Game's |
| fasta | `fasta.go-2.go` | 1.48 / 5.49 | none |
| knucleotide | `knucleotide.go-6.go` | 8.30 / 30.04 | `-7` (8.20, the fastest): it splits each k-mer count across `runtime.NumCPU()` goroutines and gives wrong output below 18 CPUs (the largest k), so its answer depends on the machine; it happens to be right on this 18-CPU one. `-6` starts `NumCPU` workers that take whole jobs from a channel, so the count changes only the schedule; its output is C's at 25,000,000 with `GOMAXPROCS` forced to 1, 4 and 18 (AUDIT.md G5) |
| revcomp | `revcomp.go-6.go` | 2.12 / 2.19 | none |
| regexredux | `regexredux.go-4.go` | 14.49 / 35.00 | `-5` (3.25, the fastest): imports `github.com/GRbit/go-pcre` and calls `MustCompileJIT`. Homebrew's PCRE1 (`pcre` 8.45) was installed for it and `go-pcre` v1.0.0 is the only release with the `Matcher` method the file calls (v1.0.1 to v1.0.3 have not); it builds, then panics on its first call (`study error`), PCRE1's JIT being unavailable here |
| pidigits | `pidigits.go-4.go` | 1.02 / 0.99 | none |

regexredux `-4` imports `github.com/mdellandrea/golang-pkg-pcre` (cgo over PCRE1, no JIT), pinned in
`programs/regexredux/go/go.mod` and `go.sum` (a go.mod is the only file added; the Game builds in a
GOPATH, and this is the version the module proxy resolves for that import). pidigits `-4` binds GMP through cgo (`#cgo LDFLAGS: -lgmp`) and calls
`runtime.GOMAXPROCS(1)` itself, as published.

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
each language pick its library ("Contentious. Different libraries."). The rule here (README, under the rules):
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
Homebrew's copy outright (build.zsh's `PCRE2_FLAGS`).

| language | archive file | library | changes |
|---|---|---|---|
| C, `c-tuned` | `regexredux.gcc-5.gcc` (the Game's fastest C) | PCRE2, JIT | unchanged: the `#pragma omp` lines are ignored without `-fopenmp` (Apple clang has none), so it runs on one thread. `c-tuned` is a copy: nothing faster than PCRE2's JIT is known for C |
| C++ | `regexredux.gpp-6.gpp` (the fastest C++) | PCRE2, JIT | `std::launch::async` changed to `std::launch::deferred`, so each task runs on the main thread when its result is asked for |
| Rust, `rust-tuned` | `regexredux.rust-7.rust` (the Game's fastest program) | PCRE2, JIT | the `pcre2_sys` and `libc` crates replaced by the `extern "C"` declarations they provide (the build is a bare `rustc` with no crates); `rayon::scope`, the `mpsc` channels and `into_par_iter` replaced by sequential calls. `rust-tuned` is a copy. **The entries using the `regex` crate (`regexredux.rust`, `-2` to `-6`) were not used**: the crate cannot be built without cargo, and the PCRE2 entry is the Game's fastest |
| Swift | `regexredux.swift-4.swift` | Foundation `NSRegularExpression` (every Swift entry's) | the `DispatchGroup` and its queues removed; the replacement chain and the counts run in turn |
| Go | `regexredux.go-4.go` (the fastest Go that runs here as published) | PCRE1 (Homebrew `pcre` 8.45, no JIT), through the cgo module `github.com/mdellandrea/golang-pkg-pcre` | unmodified. It is the library the published file imports, not PCRE2: PCRE1 is installed for it and its include and library paths are given to cgo by build.zsh. The Game's fastest, `-5`, needs PCRE1's JIT and panics here (table above). Go's own `regexp` (`regexredux.go-3.go`, 25.15 s on the Game) is about twice as slow |
| Java | `regexredux.java-2.java` (the JVM form of the fastest Java, `graalvmaot-4`) | PCRE2, JIT, through `java.lang.foreign` | the jextract-generated `jextract_pcre2.pcre2_h` (not in the archive) replaced by a nested class of hand-written downcalls to the same seven functions; the executor's tasks called in turn. Run as every Java program here, on the JVM, so the time includes startup and JIT warm-up. The JVM warns on stderr that a restricted method was called; it does not affect the output |
| Nim | none (not in the archive) | standard `std/re`, which is PCRE2 with the JIT | written for this suite. `std/re` opens `libpcre2-8.0.dylib` by name at run time, which finds macOS's JIT-less copy; `regexredux.nim.cfg` beside the source overrides that `dynlib` and links Homebrew's |
| Fortran | `regexredux.ifc` (the Game's only Fortran, a translation of `gcc-5`) | PCRE2, JIT, through `bind(C)` interfaces | built with gfortran and no `-fopenmp`, so its `!$omp` directives are comments and it runs on one thread. The `PCRE2_SIZE` arguments of `pcre2_compile` and `pcre2_jit_match` declared `integer(c_size_t)` where the archive passes `c_int`, and standard input opened as `/dev/stdin` because gfortran cannot reopen the preconnected unit for stream access |
| Zig | none | PCRE2, JIT | Zig has no regex library: **a port of the C program** above to Zig, same calls |
| D | none | standard `std.regex`, every pattern compiled to native code at compile time with `ctRegex` | written for this suite |
| Odin | none | standard `core:text/regex` (compiled to its own VM), walked with its match iterator | written for this suite. `.` matches a newline in Odin's regex, so the header pattern is spelled `>[^\n]*\n\|\n` |
| C3 | none | standard `std::encoding::experimental::regex` (POSIX ERE, musl's TNFA matcher) | written for this suite. The header pattern is compiled with `NEWLINE`, so `.` stops at a newline as in Perl |
| Ada | `regexredux.gnat-5.gnat` passed over | GNAT's `GNAT.Regpat` | written for this suite. **The Game's only working Ada entry (`gnat-5`) was not adapted**: it is not a regex program — it hand-translates each pattern into GNAT's SPITBOL pattern combinators (`BreakX`, `Any`, `Break`) — and it is five compilation units built on Ada tasks. `gnat-6` (PCRE, tasks) fails the Game's output check. A newline in the pattern is written `\n`, because `GNAT.Regpat.Compile` refuses a literal one ("junk on end") |
| Eiffel | none | Gobo's `RX_PCRE_REGULAR_EXPRESSION` (a PCRE-syntax matcher written in Eiffel), which ships with EiffelStudio | written for this suite; `regexredux.ecf` adds `$ISE_LIBRARY/library/gobo/gobo_regexp.ecf`. EiffelStudio's own PCRE binding is in its `unstable` tree and was not used. **It does not finish at the timed size**: the substitutions from `<[^>]*>` on hold memory in proportion to the run of text a `[^…]*` crosses (1.87 GB at the 10 MB input with a full collection after every step, 70 MB through the first two), so the 100 MB input is killed for memory after printing the nine counts. It verifies at the small size and its 10 MB output matches C's |

### Fortran

Fortran's programs start from the archive's Fortran entries (`*.ifc`, written for Intel Fortran; BSD-3,
headers kept), compiled with gfortran (GCC 16.2). Where the archive has several entries, the start is the
single-threaded one that is the C program's algorithm; OpenMP entries (`fannkuchredux.ifc-3`,
`mandelbrot.ifc-4`/`-6`/`-7`, `spectralnorm.ifc-3`, `binarytrees.ifc-2`) were passed over or had their
directives removed. `fannkuchredux.ifc-3` was also passed over because it caches blocks of permutations
and composes them, which is not the fixed algorithm. Every program reads its argument with
`get_command_argument`. LLVM `flang` 23 built the same sources as a check: it was faster on mandelbrot,
nbody and fasta and over four times slower on binarytrees, slower overall, and cannot use the gfortran-built
stdlib, so the column is gfortran.

| program | Fortran archive file | changes |
|---|---|---|
| nbody | `nbody.ifc-6.ifc` | the single-precision reciprocal square root with one Newton step replaced by the C program's `dt / (d2 * sqrt(d2))` in double precision; the argument buffer widened to 12 characters |
| spectralnorm | `spectralnorm.ifc-2.ifc` | `MultiplyAv`, `MultiplyAtv` and `MultiplyAtAv` are subroutines writing into preallocated arrays, where they were functions returning a fresh array, and each row is summed in a scalar |
| fannkuchredux | `fannkuchredux.ifc` | unchanged |
| binarytrees | `binarytrees.ifc` | `NewTreeNode` takes its children as pointer dummies and points the new node at them, where it passed possibly null pointers to non-pointer `target` dummies and copied a structure constructor (invalid when a child is null). A node per `allocate`, freed by `deallocate` as `ItemCheck` walks it, as in the archive |
| mandelbrot | `mandelbrot.ifc-6.ifc` | rewritten around the archive's idea (a vector of pixels iterated together until all escape): OpenMP removed; eight pixels, one output byte, per vector; the C program's coordinates `2*x/w - 1.5` and its `<= 4` test, which `NaN` fails; the image written in one unformatted stream write to `/dev/stdout` instead of a formatted `a1` per byte |
| fasta | `fasta.ifc-4.ifc` | double precision where the archive used `real` (the C program's arithmetic, so the output matches at the timed size); the C program's lookup, counting the cumulative probabilities below the random value; output lines gathered in a 64 KB buffer written by unformatted stream writes to `/dev/stdout`, where the archive called C's `puts` per line |
| knucleotide | none | **written for this suite after the C program** (the archive's `knucleotide.ifc` is a comment that there is no Fortran library hash table): see below |
| revcomp | `revcomp.ifc` | rewritten in the archive's shape (the whole input read, each record complemented through a table into a buffer from its end, re-wrapped at 60): input read with POSIX `read` through `ISO_C_BINDING` (below), output through an unformatted stream on `/dev/stdout` |

- **Reading standard input.** fasta-derived input of unknown length cannot be read in blocks by a
  conforming Fortran program: an end of file during a `READ` leaves every input item undefined, so the
  last, partial block is lost (gfortran happens to keep it; flang drops it). Line-at-a-time formatted
  reads are conforming but made revcomp five times slower than C, which is Fortran's formatted I/O
  library rather than the algorithm. revcomp and knucleotide therefore call POSIX `read(2)` through
  `ISO_C_BINDING`, as Ada's programs use `GNAT.OS_Lib`.
- **knucleotide** counts into the `open_hashmap_type` of [fortran-lang
  stdlib](https://stdlib.fortran-lang.org) 0.8.1 (`brew install fortran-stdlib`, MIT licence), keyed by
  the 2k-bit code as eight bytes, with the C program's `key xor key >> 7` as the hasher (README rule 3:
  a custom hasher is allowed). Fortran has no hash table in the language or its ISO library, and stdlib
  is the community's de facto standard library, so this is the analogue of the C program's klib
  `khash.h`. The map stores an index into parallel key and count arrays, because its values are `class(*)`;
  each lookup allocates and frees the key's copy and the value it returns, which is where the time goes
  (about 16 times the C program). The at most sixteen frequency entries are ordered by a selection sort,
  and percentages are divided in single precision, as in the C program.

### pidigits

pidigits computes with a big-integer library (README, the rules): the language's standard one where
it has one, otherwise GMP 6.3.0 (`brew install gmp`, LGPL), found with `pkg-config gmp` by
build.zsh. Every version is the reference algorithm above; the archive's `pidigits.gcc-2` (the
`lua-5` arrangement, two numerators and no `acc`), `pidigits.java` (composes 2x2 matrices of
`BigInteger`) and `pidigits.gpp-4` (`gmpxx` temporaries) do different work and were passed over.
Several archive entries print no padded last line when the count is not a multiple of ten (the
27-digit reference output has one); those gained the C++ entry's padding, noted as "padding".

| language | library | archive file | changes |
|---|---|---|---|
| C | GMP | `pidigits.gcc` | padding |
| C++ | GMP (C API) | `pidigits.gpp-5.gpp` | `using ulong = unsigned long` (a glibc name macOS lacks) |
| Rust | GMP (`#[link]` FFI, no crate) | `pidigits.rust-3.rust` | unchanged. `pidigits.rust-4` uses the `rug` crate, which the bench's crate-free `rustc` build cannot take; `-3` binds the same library directly |
| Swift | GMP (`import gmp`) | `pidigits.swift-2.swift` | unchanged; the `gmp` module is `module.modulemap` and `gmp-shim.h` beside it |
| Go | GMP (cgo) | `pidigits.go-4.go` (the fastest Go: 1.02 s on the Game, against 5.00 for `math/big` in `-7`) | unmodified. It sets `GOMAXPROCS(1)` and locks the OS thread itself, as published, and prints only whole lines of ten digits, so it is checked at the Game's 10,000 in full and at 20 digits (not 27) against the reference's first two lines (AUDIT.md G5) |
| Java | `java.math.BigInteger` | `pidigits.java-3.java` | the archive program calls GMP through a JNI wrapper library; its operations rewritten as `BigInteger` ones, the structure and output buffer kept; padding |
| Ada | GMP (`pragma Import`) | `pidigits.gnat-2.gnat` | `mpz_addmul_ui`/`mpz_submul_ui` take `unsigned_long` (the archive passed a 32-bit `unsigned` for a C `unsigned long`); `printf` imported as `C_Variadic_1`, since arm64 macOS passes variadic arguments on the stack |
| Fortran | GMP (`bind(C)`) | `pidigits.ifc-4.ifc` | unchanged |
| Zig, Nim, D, Odin, C3 | GMP (extern declarations of the `__gmpz_*` symbols) | none | **ports of the C program, written for this suite**; output through C stdio (Zig, D, C3), `stdout` (Nim) or a `bufio` writer (Odin) |
| Eiffel | GMP (`C inline` externals over `gmp.h`) | none | **a port of the C program, written for this suite**: each `mpz_t` a `malloc`ed block held as a `POINTER`; preconditions on the digit and the term, a loop invariant on the count. The `.ecf` names GMP's directories through `$GMP_INCLUDE` and `$GMP_LIB`, which build.zsh exports |
| c-tuned, rust-tuned | GMP | `pidigits.gcc`, `pidigits.rust-3.rust` | copies of the plain programs. One division per candidate digit (`mpz_tdiv_qr`: the 4num digit agrees exactly when the remainder plus `num` is below `den`), with C's output written in one call, measured slower than the plain programs' two divisions (0.260 s against 0.244 s for C, 0.261 against 0.243 for Rust) |
| sysl-idiomatic | `sysl.math.bigint` | none | written for this suite: operators between `BigInt`s, the `_long` family (`mul_long`) for a small operand |
| sysl-tuned | `sysl.math.bigint` | none | as idiomatic, with the tuned columns' one division (`div_rem`, both halves at once); `BigInt` has no in-place arithmetic, so that is the whole difference |
| `sysl-tuned-gmp` (not built) | GMP through [sysl-lang/gmp](https://github.com/sysl-lang/gmp) 0.1.0 | none | the tuned spigot on the package's in-place `Int` methods and its C layer's `mpz_tdiv_qr`; kept beside the column for the measurement of `BigInt` against GMP, and not in LANGS |

## Implementation variants of one algorithm

Some programs differ in how the same arithmetic is laid out, as they do on the Benchmarks Game. The
Rust spectral-norm and the C++ and Rust mandelbrot carry two values in a struct or eight pixels in an
array so the optimizer can vectorize, and the Rust n-body computes all pairwise differences in arrays.
They do the same operations on the same data as C and are kept; the table's ratios below 1.00 for Rust
and C++ are mostly this. The fannkuch programs generate the permutations in the same order by different
rotation schemes (C: Ledrug's; C++: Branimir Maksimovic's; Rust: a factorial-number scheme; Swift and
sysl: Rex Kerr's count array).

## The tuned C and Rust columns

`c-tuned` and `rust-tuned` follow `sysl-tuned`'s rules (README): single-threaded, the reference
algorithm above, any speed technique the language offers. Rust uses std only; its SIMD is
`core::arch::aarch64` (NEON), since `std::simd` is unstable. Each file keeps the header of the plain
program it starts from (BSD-3) and says in its own header what it changes. The fastest Benchmarks Game
entries were surveyed first: every C (`*.gcc`) and Rust (`*.rust`) entry of the eight programs that
builds on arm64 without crates was built, run single-threaded (OpenMP pragmas left inactive) and
verified; the techniques below are theirs where they apply, ported from SSE/AVX to NEON. Entries that
change the algorithm were not used: `fasta.gcc-3`'s symbol table indexed by the generator state (a
direct-indexed array), the arenas of `binarytrees.rust`-`rust-5`, and the custom hash tables of the
k-nucleotide entries.

| program | C and Rust tuned: what they do |
|---|---|
| nbody | C: the bodies as fixed arrays, one per field; each step computes the ten pairwise differences into fixed arrays, then distances and magnitudes as NEON two-lane vectors (five `fsqrt` and five `fdiv` instead of ten each), then the velocity updates. Rust: **a copy of the plain program** (`nbody.rust-2`), which already computes the pairwise differences and magnitudes in arrays: the same NEON form measured 0.950 s against its 0.867 s, and scalar or by-value variants 0.89–0.91 s. The fastest entries (`nbody.gcc-4`/`-5`/`-9`) use an approximate reciprocal square root refined by Newton steps; that replaces the per-pair sqrt and divide, so it is not used |
| spectralnorm | eight columns per step in four NEON two-lane vectors, each denominator computed exactly in double from the column vector, four independent sums so the divides overlap (the form of `spectralnorm.gcc-7` and `rust-6`, whose SSE `div_pd` becomes NEON `fdiv`) |
| fannkuchredux | the permutation is one 16-byte NEON register; a flip is one `TBL` through a reversal mask chosen at run time by the first element, the step to the next permutation one `TBL` through a rotation mask (the `pshufb` form of `fannkuchredux.gcc-4`, `gcc-6` and `rust-6`, ported to NEON); the same count-array order |
| binarytrees | each tree checked and freed in one walk (count the node, walk its children, free it), where the plain programs walk twice; every node is still its own `malloc`/`Box` and its own free |
| mandelbrot | two output bytes (sixteen pixels) per pass as eight independent NEON two-lane chains; the escape test every fifth iteration, as `sysl-tuned` does (an escaped pixel only grows, or overflows to inf/NaN, which fail `<= 4` too, so the image is the same); the image written in one call |
| fasta | the generator step's remainder by Lemire's fastmod with the multiply-add folded in (one multiply-add and one high multiply per step on the critical path, the same state sequence); the cumulative-probability scan over the whole table, branch-free, against the least integer state exceeding each probability (computed once from the C program's double comparison, so every symbol is the reference's), four per NEON compare; output in large buffers |
| k-nucleotide | khash (C) and std `HashMap` (Rust), as the plain programs, with the same hashes; 32-bit keys for k <= 16; each table sized once up front; input read whole and encoded in one pass |
| revcomp | input read whole; each record's lines joined, then reverse-complemented sixteen bytes at a time from both ends (the complement table indexed by the low five bits with one two-register `TBL`, the reversal a `REV64` plus a swap of halves), re-wrapped at 60, written in one call |
| regexredux | **copies of the plain programs**, which are already the Game's fastest entries (`gcc-5`, `rust-7`): PCRE2 with its JIT, matched with `pcre2_jit_match`. The work is the library's, and no faster regex library is in the Game's C or Rust entries |

## The two sysl forms

Both sysl forms use C's algorithm: the same work, the same arithmetic on the same data. (regex-redux,
whose work is a library's, is the exception: see its entry below.)

**`sysl-idiomatic`** is what a sysl programmer writes by default: the pleasant form, using whatever the
language offers for writing it pleasantly. That includes vectors (`<N>T`) where they are the natural
tool: mandelbrot computes the eight pixels of one output byte as one `<8>real`.

**`sysl-tuned`** may use any documented feature that trades pleasantness for speed: vectors everywhere,
fixed-size arrays, unchecked indexing, explicit layouts, manual unrolling, and, as the tuned C and
Rust programs may, what a program can do itself to get past a compiler or library gap. Each such
workaround is a "Tuned" line under its program in FINDINGS.md naming the compiler or library item
that would make it pointless. Where nothing beats the idiomatic program, `sysl-tuned` is a copy of it.

What each `sysl-tuned` program does differently from `sysl-idiomatic` (each file's own `// Tuned:`
comments are the full account):

- **nbody**: a body's position and velocity are `<3>real`, so a pair's distance, its squared length
  and both velocity updates are vector operations.
- **spectralnorm**: two columns per step, as Rust does: each step loads two elements as a `<2>real`
  and divides them by the two columns' denominators in one two-lane divide; `@unchecked`.
- **fannkuchredux**: the permutation is one `<16>u8` and a flip one constant shuffle chosen by a
  `match` on its length; `@unchecked`.
- **binarytrees**: C's node, two raw pointers, from `extern malloc` and given back by `extern free`
  in a second walk, as the plain C program does (the tuned C and Rust programs check and free in one
  walk).
- **mandelbrot**: the escape test every fifth iteration, as `c-tuned` does.
- **fasta**: the generator state in a local `u32`, the thresholds in one vector compared lane-wise,
  and the lines written a block at a time; `@unchecked`.
- **knucleotide**: a key type whose hash is one multiply (Rust's hasher), each table sized up front,
  input read with `read(2)` into `realloc`ed storage; `@unchecked`.
- **revcomp**: the input read into `realloc`ed storage, and each record reverse-complemented in place
  in its line layout, a run from each end swapped at a time; `@unchecked` around the swap.
- **regexredux**: not the same library. `sysl-idiomatic` uses the standard `sysl.regex` (POSIX ERE,
  a Pike VM; `.` matches a newline there, so the header pattern is `>[^\n]*\n|\n`) and its
  `find_all` and `replace_all`. `sysl-tuned` is C's program: PCRE2 with the JIT, through nine `extern`
  declarations of the PCRE2 functions in the file itself, because the org's `pcre2` package binds
  only the interpreter (`pcre2_match`) and allocates match data on every search. Its build passes
  `--link-path` to Homebrew's PCRE2 so that `@link("pcre2-8")` does not find macOS's JIT-less copy.
