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

## Implementation variants of one algorithm

Some programs differ in how the same arithmetic is laid out, as they do on the Benchmarks Game. The
Rust spectral-norm and the C++ and Rust mandelbrot carry two values in a struct or eight pixels in an
array so the optimizer can vectorize, and the Rust n-body computes all pairwise differences in arrays.
They do the same operations on the same data as C and are kept; the table's ratios below 1.00 for Rust
and C++ are mostly this. The fannkuch programs generate the permutations in the same order by different
rotation schemes (C: Ledrug's; C++: Branimir Maksimovic's; Rust: a factorial-number scheme; Swift and
sysl: Rex Kerr's count array).

## The two sysl forms

Both sysl forms use C's algorithm: the same work, the same arithmetic on the same data.

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
