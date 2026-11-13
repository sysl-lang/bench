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

## Implementation variants of one algorithm

Some programs differ in how the same arithmetic is laid out, as they do on the Benchmarks Game. The
Rust spectral-norm and the C++ and Rust mandelbrot carry two values in a struct or eight pixels in an
array so the optimizer can vectorize, and the Rust n-body computes all pairwise differences in arrays.
They do the same operations on the same data as C and are kept; the table's ratios below 1.00 for Rust
and C++ are mostly this. The fannkuch programs generate the permutations in the same order by different
rotation schemes (C: Ledrug's; C++: Branimir Maksimovic's; Rust: a factorial-number scheme; Swift and
sysl: Rex Kerr's count array).

## sysl-tuned and the reference algorithm

`sysl-tuned` may change how the work is done but not what work is done. What each one does differently
from `sysl-idiomatic`:

- **nbody**: `bodies[i]`'s fields are read once into locals before the inner loop and its velocity is
  accumulated in locals; `sqrt` is the `llvm.sqrt` intrinsic.
- **spectralnorm**: the denominator of row i is advanced by addition instead of recomputed from a product.
- **fannkuchredux**: the permutation state is three `[16]usize` arrays instead of heap slices.
- **binarytrees**: nodes are a struct with `Option[&Node]` children instead of an enum. Same allocation
  pattern, and no faster.
- **mandelbrot**: eight pixels per step over fixed-size arrays, always the full 50 iterations.
- **fasta**: the generator state lives in a local and the symbol is chosen by counting integer
  thresholds, which picks the same symbol as the idiomatic floating-point comparison.
- **knucleotide**: the sequence is decoded once into one preallocated array, and the hash table's key is a
  struct with a one-multiply hash. Every k-mer is still counted in a hash table.
- **revcomp**: the output is written by index into one preallocated array, not pushed byte by byte.
