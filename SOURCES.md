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

C and Rust are in their own section below, [The C and Rust entries](#the-c-and-rust-entries): each is
the Game's fastest entry that builds and runs unmodified here, multi-threaded as the Game runs it.

| program | language | archive file | changes |
|---|---|---|---|
| nbody | C++ | `nbody.gpp` | unchanged |
| nbody | Swift | `nbody.swift-5.swift` | unchanged |
| spectralnorm | C++ | `spectralnorm.gpp` | unchanged |
| spectralnorm | Swift | `spectralnorm.swift-8.swift` | unchanged |
| fannkuchredux | C++ | `fannkuchredux.gpp-3.gpp` | unchanged |
| fannkuchredux | Swift | `fannkuchredux.swift-8.swift` | unchanged |
| binarytrees | C++ | `binarytrees.gpp-2.gpp` | unchanged |
| binarytrees | Swift | `binarytrees.swift` | the Dispatch queue replaced by a sequential loop |
| mandelbrot | C++ | `mandelbrot.gpp-5.gpp` | unchanged |
| mandelbrot | Swift | `mandelbrot.swift-8.swift` | `import Glibc` changed to `import Darwin` |
| fasta | C++ | `fasta.gpp-2.gpp` | unchanged |
| fasta | Swift | none | **a port of the C program above, written for this suite**: the archive's Swift programs build a `String` a `Character` at a time (`fasta.swift-8`) or use Dispatch threads (`fasta.swift-2`, `-3`), neither of which is the C program's work |
| knucleotide | C++ | `knucleotide.gpp-3.gpp` | `__gnu_pbds::cc_hash_table` replaced by `std::unordered_map` (libc++ has no pb_ds), and the `std::async` worker per core by one call. Each k-mer's code is rolled from the previous one, as every other program does (rule 3), where the archive re-encoded all k bases at every position (AUDIT.md A4) |
| knucleotide | Swift | `knucleotide.swift-2.swift` | `concurrentPerform` over 8 tasks replaced by a loop over one task, whose table is the result (merging it into an empty table, as the threaded original must, inserted every key twice: AUDIT.md A3); the Dispatch queues removed |
| revcomp | C++ | `revcomp.gcc-4.gcc` | **the C program ported to C++** (casts on `malloc`/`realloc`, the table copied with `memcpy`). The archive's C++ programs (`revcomp.gpp`, `-2`, `-3`) read line by line through iostreams and ran 45 times slower than C, which is the I/O library rather than the algorithm |
| revcomp | Swift | `revcomp.swift` | the Dispatch reader, worker and writer queues replaced by a sequential loop |

### Go, D and Odin

Go's programs come from the same archive (`*.go` files, BSD-3, headers kept; each adapted file says
how in its header). Each is **the Game's fastest Go entry for the program on CPU time**, the measure
that carries over to one thread, with its goroutines removed (re-chosen 2026-11-20, AUDIT.md G4; the
"Game" columns are the Game's published Go measurements, wall and CPU seconds, on its 4-core x86).
Go has no optimisation level: `GOARM64=v8.7 go build`, run with `GOMAXPROCS=1` (README rule 5, rule 9).

| program | Go archive file | Game wall / CPU (s) | changes |
|---|---|---|---|
| nbody | `nbody.go-3.go` | 6.39 / 6.40, fastest | unchanged |
| spectralnorm | `spectralnorm.go-8.go` | 5.34 / 5.35, lowest CPU (ties `spectralnorm.go`) | unchanged. The fastest on wall clock, `-4` (1.43 / 5.69), is the same loops split over four goroutines |
| fannkuchredux | `fannkuchredux.go-3.go` | 8.36 / 33.33, fastest | Oleg Mazurov's chunked permutation walk, as C's `-3`. The goroutine each chunk starts for the next replaced by `main` running every chunk in turn; `runtime.GOMAXPROCS(4)` removed |
| binarytrees | `binarytrees.go-6.go` | 27.93 / 29.26, lowest CPU | unchanged: single-threaded; every node is its own `&Node{}`, recycled through `sync.Pool` when its tree is checked (AUDIT.md G3). The fastest on wall clock (`-2`, 56.53 CPU) is goroutines over plain allocation |
| mandelbrot | `mandelbrot.go-4.go` | 3.77 / 15.01, fastest | two pixels per inner loop, 50 iterations, C's escape test. The 2 x `NumCPU` workers taking rows from an atomic counter replaced by `main` rendering every row; `runtime.GOMAXPROCS` removed. Each coordinate computed as C computes it, `2*x/size`, where the archive's `x*(2/size)` rounds some boundary pixels the other way: its output differed from the Game's own at 200 and from C's at 6,000 (AUDIT.md G5). The coordinates are computed once, outside the timed loop's work |
| fasta | `fasta.go` | 3.74 / 3.75, lowest CPU | unchanged: single-threaded, linear scan of the cumulative probabilities |
| knucleotide | `knucleotide.go-7.go` | 7.58 / 28.88, fastest | a built-in `map[uint32]*int` / `map[uint64]*int` keyed by the 2k-bit code. `runtime.NumCPU()` replaced by 1, so there is one table per k, rolled one base at a time, and the workers called rather than started with `go`. The roll shifts in the k-mer's last base (`data[idx+size-nsize+i]`); the archive shifts in `data[idx+i]`, right only when the goroutine count is at least k, and with one goroutine it counted wrong k-mers (AUDIT.md G5) |
| revcomp | `revcomp.go-2.go` | 2.22 / 2.32, lowest CPU | unchanged: single-threaded. The fastest on wall clock, `-6` (1.93 / 3.43), is threaded |

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
| C | `regexredux.gcc-5.gcc` (the Game's fastest C) | PCRE2, JIT | unchanged, multi-threaded with OpenMP (see [The C and Rust entries](#the-c-and-rust-entries)) |
| C++ | `regexredux.gpp-6.gpp` (the fastest C++) | PCRE2, JIT | `std::launch::async` changed to `std::launch::deferred`, so each task runs on the main thread when its result is asked for |
| Rust | `regexredux.rust-7.rust` (the Game's fastest program) | PCRE2, JIT, through the `pcre2-sys` crate | unchanged, multi-threaded with rayon; built with Cargo, `pcre2-sys` finding Homebrew's PCRE2 through `pkg-config` (see [The C and Rust entries](#the-c-and-rust-entries)) |
| Swift | `regexredux.swift-4.swift` | Foundation `NSRegularExpression` (every Swift entry's) | the `DispatchGroup` and its queues removed; the replacement chain and the counts run in turn |
| Go | `regexredux.go-5.go` (the fastest Go) | PCRE2, JIT, through cgo | the archive program imports `github.com/GRbit/go-pcre`, a cgo binding to the retired PCRE1 (not installed, and a module fetch); it is replaced by a few dozen lines of cgo over PCRE2 making the same calls (`pcre2_jit_compile`, `pcre2_jit_match`). Goroutines and `GOMAXPROCS` removed. Go's own `regexp` (`regexredux.go`, `-3`) is about eight times slower on the Game. The cgo flags come from PCRE2's `pkg-config` file, Homebrew's named outright by build.zsh |
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
`BigInteger`) and `pidigits.gpp-4` (`gmpxx` temporaries) do different work and were passed over, except
that C is now `pidigits.gcc-2` itself: C and Rust are each the Game's fastest entry as published
(D-BENCH2TRACK, [The C and Rust entries](#the-c-and-rust-entries)).
Several archive entries print no padded last line when the count is not a multiple of ten (the
27-digit reference output has one); those gained the C++ entry's padding, noted as "padding".

| language | library | archive file | changes |
|---|---|---|---|
| C | GMP | `pidigits.gcc-2.gcc` | unchanged (the Game's fastest C, used as published under D-BENCH2TRACK; see [The C and Rust entries](#the-c-and-rust-entries)) |
| C++ | GMP (C API) | `pidigits.gpp-5.gpp` | `using ulong = unsigned long` (a glibc name macOS lacks) |
| Rust | GMP through the `rug` crate | `pidigits.rust-4.rust` | unchanged (the Game's fastest program); `rug` links Homebrew's GMP (see [The C and Rust entries](#the-c-and-rust-entries)) |
| Swift | GMP (`import gmp`) | `pidigits.swift-2.swift` | unchanged; the `gmp` module is `module.modulemap` and `gmp-shim.h` beside it |
| Go | GMP (cgo) | `pidigits.go-4.go` (the fastest Go: 0.82 s on the Game, against 5.00 for `math/big` in `-7`) | padding (the archive program prints only whole lines of ten). It sets `GOMAXPROCS(1)` and locks the OS thread itself. Until 2026-11-17 Go ran `-7` over `math/big`, about six times slower on the Game, while every other language here used GMP (AUDIT.md G4) |
| Java | `java.math.BigInteger` | `pidigits.java-3.java` | the archive program calls GMP through a JNI wrapper library; its operations rewritten as `BigInteger` ones, the structure and output buffer kept; padding |
| Ada | GMP (`pragma Import`) | `pidigits.gnat-2.gnat` | `mpz_addmul_ui`/`mpz_submul_ui` take `unsigned_long` (the archive passed a 32-bit `unsigned` for a C `unsigned long`); `printf` imported as `C_Variadic_1`, since arm64 macOS passes variadic arguments on the stack |
| Fortran | GMP (`bind(C)`) | `pidigits.ifc-4.ifc` | unchanged |
| Zig, Nim, D, Odin, C3 | GMP (extern declarations of the `__gmpz_*` symbols) | none | **ports of the C program, written for this suite**; output through C stdio (Zig, D, C3), `stdout` (Nim) or a `bufio` writer (Odin) |
| Eiffel | GMP (`C inline` externals over `gmp.h`) | none | **a port of the C program, written for this suite**: each `mpz_t` a `malloc`ed block held as a `POINTER`; preconditions on the digit and the term, a loop invariant on the count. The `.ecf` names GMP's directories through `$GMP_INCLUDE` and `$GMP_LIB`, which build.zsh exports |
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

## The C and Rust entries

**C and Rust are each the Benchmarks Game's fastest entry, by elapsed time on the Game's multi-core
table, that builds and runs unmodified on this machine (arm64 macOS)**, multi-threaded as the Game
runs it (decision D-BENCH2TRACK). The rankings are the Game's `performance/<program>.html` pages and the
build lines its `program/<entry>.html` pages, fetched 2026-11-20; the files are the source archive's of
the same day. **No source line is changed**: each `programs/<program>/c/<program>.c` and
`programs/<program>/rust/<program>.rs` is byte-for-byte the archive file named below. An entry that
does not build or run correctly here as published was passed over for the next fastest, and is listed
with the reason under *Entries passed over*.

**What differs from the Game's build, and only this** (build.zsh):

- **C:** Apple clang 21, not gcc 14. The Game's `gcc -pipe -Wall -O3 -fomit-frame-pointer
  -march=ivybridge` becomes `clang -std=gnu17 -pipe -O3 -fomit-frame-pointer -mcpu=native -w` (gnu17 is
  gcc 14's default; `-mcpu=native` per AUDIT.md A1). `-fopenmp` is Apple clang's `-Xpreprocessor
  -fopenmp` with Homebrew's libomp (`-I`/`-L` its directories, `-lomp`), since Apple clang ships no
  OpenMP runtime. Libraries are Homebrew's: GMP, PCRE2 (with its JIT), APR (`-I…/include/apr-1`, for
  the Game's `-I/usr/include/apr-1`). k-nucleotide's `-IInclude` (klib's `khash.h`) is the program's
  own directory, which holds `khash.h`.
- **mandelbrot C: `-ffp-contract=off`.** The program's own header says to compile with `-mno-fma`;
  the Game's Ivy Bridge has no FMA, so its gcc never fuses. Apple clang on arm64 fuses `a*b+c` by
  default, which moves pixels across the escape boundary (the 200-pixel reference output fails), and
  `-ffp-contract=off` is arm64's spelling of the same arithmetic.
- **Rust:** rustc 1.94 through Cargo, not a bare rustc 1.84.1. Each `rust/` directory has a
  `Cargo.toml` naming only the crates its entry's `extern crate` lines (and Game page) name, and its
  `Cargo.lock`; `edition = "2015"`, the edition of the Game's bare `rustc`; `opt-level = 3`,
  `codegen-units = 1`, and `RUSTFLAGS=-C target-cpu=native` for `-C target-cpu=ivybridge`. The Game
  publishes no crate versions, so each is the newest of the major version the entry's API is written
  against: rayon 1.12.0, bumpalo 3.20.4, num_cpus 1.17.0, spin 0.9.9, futures 0.1.31,
  tokio-threadpool 0.1.18, itertools 0.14.0, num 0.4.3, hashbrown 0.15.5, rug 1.30.0, libc 0.2.191,
  pcre2-sys 0.2.10, memchr 2.8.3. Crates are fetched into `build/.cargo-home` (a `CARGO_HOME` inside the
  repo's ignored build directory, so nothing user-wide is written).
- **pidigits Rust:** `rug` with only its `integer` feature, and its own binding `gmp-mpfr-sys` named
  with `use-system-libs`, so it links Homebrew's GMP, the library the C program links, instead of
  compiling a second GMP from source. **regexredux Rust:** `pcre2-sys` finds Homebrew's PCRE2 through
  `pkg-config` (build.zsh sets `PKG_CONFIG_PATH`), not macOS's JIT-less copy.

| program | C entry | its threading | Rust entry | its threading and crates |
|---|---|---|---|---|
| nbody | `nbody.gcc-6.gcc` (Game 4.98 s) | single-threaded | `nbody.rust-3.rust` (3.46 s) | single-threaded; no crates |
| spectralnorm | `spectralnorm.gcc-3.gcc` (1.43 s) | OpenMP | `spectralnorm.rust-5.rust` (0.72 s) | rayon |
| fannkuchredux | `fannkuchredux.gcc-5.gcc` (7.28 s) | OpenMP | `fannkuchredux.rust-4.rust` (6.94 s) | rayon |
| binarytrees | `binarytrees.gcc-2.gcc` (1.56 s, the fastest C) | OpenMP; APR pools | `binarytrees.rust-5.rust` (1.07 s, the fastest program) | rayon; bumpalo arenas |
| mandelbrot | `mandelbrot.gcc-5.gcc` (1.64 s) | OpenMP | `mandelbrot.rust-4.rust` (0.95 s, the fastest program) | rayon |
| fasta | `fasta.gcc-3.gcc` (0.79 s, the fastest C) | single-threaded | `fasta.rust-7.rust` (0.78 s, the fastest program) | threads (`num_cpus`, `spin::Mutex`); its SSE2 lookup is `#[cfg(target_feature = "sse2")]`, so its own scalar path builds here |
| knucleotide | `knucleotide.gcc` (3.58 s, the fastest C) | OpenMP; khash | `knucleotide.rust-7.rust` (2.57 s, the fastest program) | tokio-threadpool and futures 0.1; hashbrown, itertools, num |
| revcomp | `revcomp.gcc-9.gcc` (0.49 s) | pthreads | `revcomp.rust` (0.55 s) | rayon; memchr. Its SSSE3 path is `#[cfg(target_feature = "ssse3")]`, so its own fallback builds here |
| regexredux | `regexredux.gcc-5.gcc` (0.81 s, the fastest C) | OpenMP; PCRE2 JIT | `regexredux.rust-7.rust` (0.78 s, the fastest program) | rayon; pcre2-sys (PCRE2 JIT), libc |
| pidigits | `pidigits.gcc-2.gcc` (0.74 s, the fastest C) | single-threaded; GMP | `pidigits.rust-4.rust` (0.71 s, the fastest program) | single-threaded; rug (GMP) |

The times are the Game's elapsed seconds on its four-core Ivy Bridge, for ranking only; nothing here
is timed against them.

### Entries passed over

Faster entries that do not build or run unmodified here, in the Game's order:

| program | entry (Game elapsed) | why it was passed over |
|---|---|---|
| nbody | `nbody.gcc-9.gcc` (2.10 s) | x86 AVX intrinsics: `#include <immintrin.h>`, which clang refuses on arm64 |
| nbody | `nbody.gcc-4.gcc` (4.06 s) | x86 SSE intrinsics (`immintrin.h`, `_mm_rsqrt_ps`) |
| nbody | `nbody.rust-9.rust` (2.19 s), `nbody.rust-7.rust` (3.24 s) | `use std::arch::x86_64::*` unconditionally: `unresolved import std::arch::x86_64` |
| spectralnorm | `spectralnorm.gcc-6.gcc` (0.40 s) | x86 AVX intrinsics (`immintrin.h`) |
| spectralnorm | `spectralnorm.gcc-5.gcc` (0.72 s) | x86 SSE2 intrinsics (`emmintrin.h`); also `#include <malloc.h>`, absent on macOS |
| spectralnorm | `spectralnorm.rust-6.rust` (0.72 s) | builds (its SSE2 module is behind `cfg`) but panics at run time: "This only works with SSE2" |
| spectralnorm | `spectralnorm.gcc-7.gcc` (0.72 s) | x86 intrinsics (`immintrin.h`) and `malloc.h` |
| spectralnorm | `spectralnorm.gcc-4.gcc` (0.72 s) | Linux CPU affinity: `cpu_set_t` (`sched_setaffinity`), absent on macOS |
| fannkuchredux | `fannkuchredux.gcc-6.gcc` (2.14 s) | x86 SSE4.1 intrinsics (`smmintrin.h`, `pshufb`) |
| fannkuchredux | `fannkuchredux.rust-6.rust` (3.81 s) | `use std::arch::x86_64::{_mm_shuffle_epi8, …}` unconditionally |
| mandelbrot | `mandelbrot.gcc-6.gcc` (1.29 s) | x86 SSE2 intrinsics (`emmintrin.h`, `__m128d`) |
| revcomp | `revcomp.gcc-7.gcc` (0.44 s) | `#include <immintrin.h>` unconditionally (its SSE4.1 code is behind `#ifdef __SSE4_1__`, the include is not) |

Nothing was passed over for C on binarytrees, fasta, knucleotide, regexredux and pidigits, nor for
Rust on binarytrees, fasta, knucleotide, mandelbrot, revcomp, regexredux and pidigits: there the
entry used is the Game's fastest in its language. Where the Game's two-decimal times tie (spectral-norm's 0.72 s group), its
listed order is the order used.

The single-threaded expert `c-tuned` and `rust-tuned` columns of decision D-TUNED were removed with
this change (their files are in git history); AUDIT.md records why.

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
