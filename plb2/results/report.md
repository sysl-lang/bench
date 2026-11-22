# plb2 results — 2026-11-22T11:11:49-05:00

Apple M5 Pro (Mac17,8), 27.0.1; hyperfine 2.0.0, `-N --warmup 1`, order shuffled from seed 1795363644.

Mean wall time ± standard deviation in seconds, and the ratio to C (lower is faster).

| program | C | Rust | Zig | Swift | Nim | D | sysl |
|---|---:|---:|---:|---:|---:|---:|---:|
| nqueen | 1.770 ± 0.009 (1.00×) | 1.831 ± 0.016 (1.03×) | does not build | 2.000 ± 0.030 (1.13×) | 1.756 ± 0.017 (0.99×) | 1.777 ± 0.006 (1.00×) | 1.930 ± 0.026 (1.09×) |
| matmul | 0.381 ± 0.001 (1.00×) | 0.385 ± 0.001 (1.01×) | does not build | 0.382 ± 0.002 (1.00×) | 0.384 ± 0.001 (1.01×) | 0.387 ± 0.001 (1.02×) [1] | 0.380 ± 0.002 (1.00×) |
| sudoku | 1.102 ± 0.003 (1.00×) | 1.169 ± 0.008 (1.06×) | no upstream program | 1.155 ± 0.003 (1.05×) | 1.090 ± 0.002 (0.99×) [2] | 1.085 ± 0.002 (0.98×) | 1.097 ± 0.003 (1.00×) |
| bedcov | 0.609 ± 0.015 (1.00×) | 0.684 ± 0.005 (1.12×) [3] | no upstream program | 0.779 ± 0.007 (1.28×) | 0.657 ± 0.012 (1.08×) | 0.640 ± 0.008 (1.05×) | 0.632 ± 0.014 (1.04×) |
| **geomean vs C** | **1.00×** | **1.04×** (over 3) | — | **1.11×** | **1.02×** | **1.01×** | **1.03×** |

CPU time (user + system), mean seconds:

| program | C | Rust | Zig | Swift | Nim | D | sysl |
|---|---:|---:|---:|---:|---:|---:|---:|
| nqueen | 1.768 | 1.829 | — | 1.998 | 1.754 | 1.776 | 1.928 |
| matmul | 0.379 | 0.384 | — | 0.381 | 0.383 | 0.386 | 0.379 |
| sudoku | 1.101 | 1.168 | — | 1.154 | 1.088 | 1.084 | 1.096 |
| bedcov | 0.607 | 0.682 | — | 0.777 | 0.655 | 0.639 | 0.630 |

[1] D matmul: prints -143.5: right to the 1 decimal(s) printed
[2] Nim sudoku: the same solutions, without the blank line after each puzzle
[3] Rust bedcov: WRONG ANSWER — prints 8195479573, C prints 8195494005

Toolchains:

- C: Apple clang version 21.0.0 (clang-2100.4.1.1) — flags `-O3 -fwrapv -flto`
- Rust: rustc 1.94.0 (4a4ef493e 2026-03-02) — flags `-C debuginfo=0 -C opt-level=3`
- Zig: 0.17.1 — flags `-O ReleaseFast`
- Swift: swift-driver version: 1.168.6 Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1) — flags `-Ounchecked`
- Nim: Nim Compiler Version 2.4.2 [MacOSX: arm64] — flags `-d:release -d:lto --bound_checks:off --overflow_checks:off -d:nimEmulateOverflowChecks`
- D: LDC - the LLVM D compiler (1.43.0): — flags `-O3 -release`
- sysl: sysl 0.13.0 — flags `--release -O3 --lto full`
