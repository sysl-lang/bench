# plb2 — methodology

## The programs

Every non-sysl program is upstream's file at commit `1181b3b83fea52ee85a66548845f8bf92e33fb67`,
byte for byte. A program upstream does not have (Zig's sudoku and bedcov) is absent, and one that
does not compile on today's toolchain (Zig's nqueen and matmul, on Zig 0.17.1) is reported with its
error and not edited. Fixing either would make it this benchmark's program, not upstream's.

The sysl programs port upstream's C: the same algorithm, data layout and loop order, written as
idiomatic sysl rather than transliterated (slices and row views for matmul's row pointers, a `Buf`
for bedcov's realloc'd array, index buckets for its radix sort's pointer pairs, a `panic` for
nqueen's `abort`). Bounds checks stay on: sysl's `--release` keeps them, and nothing in the ports
turns them off.

## Flags

Each upstream language takes its own Makefile's flags, quoted in `scripts/flags.zsh`; the build maps
only output, cache and object paths.

| language | flags | memory management (upstream's default) |
|---|---|---|
| C | `cc -O3 -fwrapv -flto` | manual |
| Rust | `rustc -C debuginfo=0 -C opt-level=3` | ownership |
| Swift | `swiftc -Ounchecked` | ARC |
| Zig | `zig build-exe -O ReleaseFast` | manual |
| Nim | `nim c -d:release -d:lto --bound_checks:off --overflow_checks:off -d:nimEmulateOverflowChecks` | Nim 2's default, ORC (reference counting with a cycle collector) |
| D | `ldc2 -O3 -release` | D's garbage collector (`-release` also removes bounds checks) |
| sysl | `sysl build --release -O3 --lto full` | ARC |

sysl takes C's: `-O3` and full LTO, with `--release`, whose integers wrap as `-fwrapv` makes C's.
No upstream Makefile names a processor, so no language here is built for the native one. Swift's
`-Ounchecked`, Nim's `--bound_checks:off` and D's `-release` remove checks that sysl keeps.

## Checking

`scripts/verify.py` runs every built program once and compares it with upstream C's output, recorded
in `expected/`: exactly for nqueen and bedcov, by SHA-256 for sudoku's 8000 lines, and to a relative
1e-8 for matmul, whose one number every language prints in its own format. A right answer printed
differently (D's six digits, Nim's missing blank lines) is marked as such; a wrong one is timed and
marked, and left out of its language's geometric mean.

## Timing

As upstream's README does: hyperfine, wall-clock time of the whole process, default sizes, no
arguments. Each program runs with `hyperfine -N --warmup 1` (no shell; hyperfine's default run count,
at least ten), the (program, language) pairs in an order shuffled from a seed recorded in
`results/meta.json`. The report gives the mean ± standard deviation, the ratio of the mean to C's,
the CPU time (user + system), and each language's geometric mean of its ratios over the programs it
has. The results were taken on one machine (`results/meta.json`), with nothing else admitted to run.

## Threats to validity

Four programs, a few dozen lines each, measure loops, not languages: one vectorisation decision moves
matmul by a factor. Startup time is inside every number (runs are 0.4–2 s for C). Upstream's
programs are not all equally tuned, and they are timed as upstream wrote them.
