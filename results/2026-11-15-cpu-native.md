# Results 2026-11-15

Apple M5 Pro, macOS 27.0.1. Single-threaded, `hyperfine --warmup 3 --runs 10`.

Each cell is the mean time as a ratio to C (1.00 = as fast as C, higher is slower). The `C (s)` column is C's own mean in seconds.

Load average at the start and end of the run (`uptime`); if other builds were running, the figures were measured under load and are noisier than an idle-machine run:

```
18:12  up 3 days, 10:04, 12 users, load averages: 1.86 1.88 4.08
18:27  up 3 days, 10:20, 12 users, load averages: 1.57 1.45 2.31
```

| program | C (s) | rust | cpp | swift | zig | nim | julia | sysl-idiomatic | sysl-fast |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nbody | 1.463 | 0.58 | 0.71 | 1.00 | 0.85 | 0.99 | 1.84 | 0.91 | 0.60 |
| spectralnorm | 0.883 | 0.36 | 0.74 | 0.84 | 0.79 | 0.75 | 0.96 | 0.98 | 0.57 |
| fannkuchredux | 1.450 | 0.96 | 0.98 | 1.04 | 0.91 | 0.94 | 1.08 | 0.90 | 0.91 |
| binarytrees | 0.615 | 1.21 | 1.22 | 3.01 | 0.95 | 0.70 | 1.05 | 1.27 | 1.21 |
| mandelbrot | 0.907 | 0.41 | 0.54 | 1.11 | 1.12 | 1.03 | 1.20 | 0.31 | 0.31 |
| fasta | 0.576 | 1.87 | 1.10 | 1.40 | 1.08 | 1.38 | 1.17 | 1.17 | 1.17 |
| knucleotide | 1.027 | 0.84 | 2.43 | 5.01 | 1.25 | 1.60 | 3.78 | 1.40 | 1.39 |
| revcomp | 0.085 | 0.45 | 0.96 | 0.73 | 0.81 | 2.17 | 2.10 | 1.92 | 1.91 |
| **geometric mean** | | 0.72 | 0.98 | 1.40 | 0.96 | 1.12 | 1.47 | 1.00 | 0.88 |

## CPU time

The same ratios computed from CPU time (user plus system) instead of wall-clock time, which a busy machine disturbs less.

| program | C (s) | rust | cpp | swift | zig | nim | julia | sysl-idiomatic | sysl-fast |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nbody | 1.461 | 0.58 | 0.71 | 1.00 | 0.85 | 0.99 | 1.84 | 0.91 | 0.60 |
| spectralnorm | 0.882 | 0.36 | 0.74 | 0.84 | 0.79 | 0.75 | 0.96 | 0.98 | 0.57 |
| fannkuchredux | 1.448 | 0.96 | 0.98 | 1.04 | 0.91 | 0.94 | 1.07 | 0.90 | 0.91 |
| binarytrees | 0.614 | 1.21 | 1.22 | 3.01 | 0.95 | 0.70 | 1.05 | 1.27 | 1.21 |
| mandelbrot | 0.906 | 0.41 | 0.54 | 1.11 | 1.12 | 1.03 | 1.20 | 0.31 | 0.31 |
| fasta | 0.575 | 1.87 | 1.10 | 1.40 | 1.08 | 1.38 | 1.17 | 1.17 | 1.17 |
| knucleotide | 1.025 | 0.84 | 2.43 | 5.01 | 1.25 | 1.60 | 3.77 | 1.40 | 1.39 |
| revcomp | 0.084 | 0.44 | 0.96 | 0.73 | 0.80 | 2.16 | 2.07 | 1.91 | 1.91 |
| **geometric mean** | | 0.72 | 0.98 | 1.40 | 0.96 | 1.11 | 1.47 | 1.00 | 0.88 |

## Toolchains

- **sysl**: sysl 0.11.3
- **c**: Apple clang version 21.0.0 (clang-2100.4.1.1) (LLVM: 21.0.0 (clang-2100.4.1.1))
- **cpp**: Apple clang version 21.0.0 (clang-2100.4.1.1) (LLVM: 21.0.0 (clang-2100.4.1.1))
- **rust**: rustc 1.94.0 (4a4ef493e 2026-03-02) (LLVM: 21.1.8)
- **swift**: Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1) (LLVM: 21.0.0 (clang-2100.4.1.1))
- **zig**: zig 0.17.1
- **nim**: Nim Compiler Version 2.4.0 [MacOSX: arm64] (LLVM: 21.0.0 (clang-2100.4.1.1))
- **julia**: julia version 1.13.3
- **hyperfine**: hyperfine 2.0.0

## Flags

- **sysl**: `sysl build --release -O3 --cpu native`
- **c**: `clang -std=gnu17 -O3 -march=native`
- **cpp**: `clang++ -std=c++20 -O3 -march=native`
- **rust**: `rustc --edition 2021 -C opt-level=3 -C target-cpu=native`
- **swift**: `swiftc -O`
- **zig**: `zig build-exe -O ReleaseFast -mcpu=native -fsingle-threaded`
- **nim**: `nim c -d:danger --opt:speed --mm:orc --cc:clang --passC:-march=native --threads:off`
- **julia**: `julia -O3 --check-bounds=no --startup-file=no (JIT: every timed run includes Julia's startup and compilation, as on the Benchmarks Game)`
