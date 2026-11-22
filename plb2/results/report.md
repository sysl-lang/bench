# plb2 results — 2026-11-22T01:54:10-05:00

Apple M5 Pro (Mac17,8), 27.0.1; hyperfine 2.0.0, `-N --warmup 1`, order shuffled from seed 1795330186.

Mean wall time ± standard deviation in seconds, and the ratio to C (lower is faster).

| program | C | Rust | Zig | Swift | Nim | D | sysl |
|---|---:|---:|---:|---:|---:|---:|---:|
| nqueen | 1.772 ± 0.007 (1.00×) | 1.823 ± 0.008 (1.03×) | does not build | 1.992 ± 0.029 (1.12×) | 1.745 ± 0.018 (0.98×) | 1.778 ± 0.006 (1.00×) | 1.912 ± 0.035 (1.08×) |
| matmul | 0.385 ± 0.002 (1.00×) | 0.391 ± 0.001 (1.02×) | does not build | 0.385 ± 0.001 (1.00×) | 0.386 ± 0.001 (1.00×) | 0.387 ± 0.001 (1.01×) [1] | 0.386 ± 0.001 (1.00×) |
| sudoku | 1.103 ± 0.002 (1.00×) | 1.161 ± 0.003 (1.05×) | no upstream program | 1.153 ± 0.001 (1.05×) | 1.090 ± 0.007 (0.99×) [2] | 1.086 ± 0.002 (0.98×) | 1.100 ± 0.002 (1.00×) |
| bedcov | 0.596 ± 0.006 (1.00×) | 0.653 ± 0.003 (1.10×) [3] | no upstream program | 0.777 ± 0.005 (1.30×) | 0.661 ± 0.018 (1.11×) | 0.632 ± 0.010 (1.06×) | 0.614 ± 0.003 (1.03×) |
| **geomean vs C** | **1.00×** | **1.03×** (over 3) | — | **1.11×** | **1.02×** | **1.01×** | **1.03×** |

CPU time (user + system), mean seconds:

| program | C | Rust | Zig | Swift | Nim | D | sysl |
|---|---:|---:|---:|---:|---:|---:|---:|
| nqueen | 1.770 | 1.821 | — | 1.990 | 1.743 | 1.776 | 1.909 |
| matmul | 0.383 | 0.390 | — | 0.383 | 0.384 | 0.386 | 0.384 |
| sudoku | 1.101 | 1.159 | — | 1.151 | 1.088 | 1.085 | 1.099 |
| bedcov | 0.594 | 0.651 | — | 0.775 | 0.659 | 0.631 | 0.612 |

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
- sysl: sysl dev 21073aae (pre-0.13.0) — flags `--release -O3 --lto full`
