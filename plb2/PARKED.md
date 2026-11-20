# plb2 track — PARKED (WIP)

Parked on the user's instruction (focus moved to AWFY). Branch `plb2`, worktree
`/Users/ed/dev/sysl-lang/bench-plb2`, made from origin/dev 2446481. This file is enough to resume from.

## The task

The task is to add Heng Li's plb2 (https://github.com/attractivechaos/plb2) as a third benchmark in a
self-contained `plb2/` folder. It runs four programs (nqueen, matmul, sudoku, bedcov) in the bench's 11
languages (sysl, C, C++, Rust, Go, Zig, Swift, Ada, Fortran, Odin, C3). Upstream programs are used
byte-identical. A language upstream lacks gets original programs, labelled "original, written for this
benchmark". The folder holds `reproduce.zsh` (no marshal), `report.py` (Markdown + self-contained
`results/report.html`), a README with "Reproducing", and METHODOLOGY.md. Builds go through marshal at
normal priority. The only timing allowed is ONE exclusive check job of the written programs against C.

## Done

- `plb2/upstream/` is upstream at commit **1181b3b83fea52ee85a66548845f8bf92e33fb67** (2025-01-30,
  "updated Codon to v0.18.0"), the whole tree, extracted with `git archive`. It is unmodified.
- Licence: upstream's LICENSE is CC0 1.0. `src/c/sudoku.c` carries its own MIT header (Attractive Chaos).
- `plb2/scripts/lib.zsh` holds the SRC table, which decides each program's provenance in one place, plus
  PATH, the languages and the programs.
- `plb2/scripts/flags.zsh` holds the per-language flags, with upstream's Makefile flags quoted.
- `plb2/scripts/build.zsh` builds into `plb2/build/bin/<prog>/<lang>`. `build/` is git-ignored by the
  top-level `.gitignore`.

## Verified (marshal job 8169)

- **These upstream programs build unmodified on today's toolchains:** C, Rust, Go and Swift (all four
  programs each), and Fortran nqueen, matmul and sudoku.
- **Upstream's Zig (nqueen, matmul; written for Zig 0.11) does NOT compile on Zig 0.17.1:**
  - nqueen: `upstream/src/zig/nqueen.zig:5:21: error: binary operator '*' has whitespace on one side, but not the other`
  - matmul: `upstream/src/zig/matmul.zig:4:13: error: local variable is never mutated`

  Decision: all four Zig programs are written. Upstream's Zig is vendored and disclosed, not edited.
- **Upstream C outputs** (cc -O3 -fwrapv -flto, M5 Pro, wall time of one run):
  - nqueen `2279184` (1.88 s). This matches OEIS A000170 for n = 15.
  - matmul `-143.500167` (0.41 s).
  - sudoku: 8000 lines, i.e. 4000 solutions each followed by a blank line (1.18 s).
  - bedcov `8195494005` (0.65 s).
- **Output formats differ:** Rust prints matmul with `{}` and upstream Zig used stderr. So matmul must be
  verified numerically (relative tolerance about 1e-8). The other three can be compared exactly.

## Provenance plan (the SRC table in lib.zsh)

| Language | Source of the four programs |
|---|---|
| C, Rust, Go, Swift | upstream, unmodified |
| Fortran | upstream nqueen, matmul and sudoku; bedcov written |
| Zig | all four written (see the build failure above) |
| C++, Ada, Odin, C3, sysl | all four written (upstream has none) |

## Decisions taken (to justify in METHODOLOGY.md)

- **Upstream's languages use upstream's flags exactly**, from each `src/<lang>/Makefile`:
  - C: `-O3 -fwrapv -flto`
  - Rust: `-C debuginfo=0 -C opt-level=3`
  - Go: plain `go build`
  - Swift: `-Ounchecked`
  - Zig: `-O ReleaseFast` (Zig's default CPU is native)
  - Fortran: `-O3`

  No upstream Makefile names a CPU, so no `-mcpu=native` anywhere. The only mapping is output paths and
  cache or module directories.
- **Written languages:**
  - C++: `-std=c++20 -O3 -fwrapv -flto` (C's flags)
  - sysl: `--release -O3 --lto full` (C's -O3/-flto; `--release` wraps like -fwrapv)
  - Ada: `-O3 -gnatp`
  - Odin: `-o:speed`
  - C3: `-O3`

  These are the bench's other tracks' flags without native.
- **Timing follows upstream** (its README): hyperfine, wall-clock elapsed time, default sizes, no
  arguments. Planned: `-N --warmup 1`, with the order of the (program, language) pairs shuffled from a
  recorded seed, and user and system CPU recorded from hyperfine's JSON.
- **GOMAXPROCS is left unset.** Upstream measures elapsed time and discusses runtime threads explicitly
  (README "Elapsed time vs CPU time"). Report CPU time beside it. This differs from the other tracks'
  GOMAXPROCS=1, so disclose it.
- **No data files:** the sudoku puzzles are embedded (hard20 × 200) and bedcov generates its data with
  splitmix32 (seed 11).
- **Languages left out, with reasons to write:**
  - GC or JIT: Java, C#, D, Nim, Crystal, V (Boehm GC by default), OCaml, Common Lisp/SBCL, Dart,
    Elixir, JavaScript, Julia, Lua/LuaJIT, Perl, PHP, Python/PyPy/Codon, Ruby, Scheme.
  - Mojo is AOT and not GC, but it is outside the bench's language set and upstream has only nqueen and
    matmul for it. Say so; it is not a STOP item.

## In progress (nothing written yet)

The sysl port was being designed from the C version:
- nqueen: fixed `[31]` arrays, `u32` masks, and a `panic` from `sysl.check` for C's abort.
- matmul: one `[]real` of n*n plus a `[][]real` table of row sub-slices, mirroring C's calloc'd block and
  its row-pointer array. The inner loop is `ci[j] += aik * bk[j]` over local views, so loop versioning
  drops the checks.
- sudoku: `struct Aux { r: [324][9]u16, c: [729][4]u16 }` held as `&Aux`. `sr`/`sc` are local fixed
  arrays passed as views. Output uses `putbytes`.
- bedcov: still to design. It needs the radix sort, splitmix32 (`+%`/`*%`), the implicit interval tree
  and a growable output buffer.

Useful sysl facts:
- `++`/`--` are expressions (postfix yields the old value), so `if sr[rr]++ != 0` ports directly.
- Bitwise operators bind tighter than comparison.
- A shift count may be any integer type, and over-width shifts are defined.
- `a*b + c` is fused, as under clang's default.
- `int` is 32 bits, `long` 64, `real` f64.

## Next steps

1. Write the 25 programs in `written/<lang>/`. Write sysl first. **Rule 9:** if sysl cannot express
   something cleanly, stop that program and report it.
2. Write `expected/` (nqueen.txt, matmul.txt, bedcov.txt, sudoku.sha256 plus one 20-puzzle block) and
   `scripts/verify.py`.
3. Write the rest of the scripts:
   - `scripts/check-upstream.zsh`: an `upstream.sha256` manifest plus a `--git` re-clone compare.
   - `scripts/toolchains.zsh`: versions and install hints.
   - `scripts/time.zsh`: hyperfine to raw JSON.
   - `plb2/reproduce.zsh`
   - `plb2/report.py`: mean ± sd, ratios to C, a geomean with a bootstrap CI, and an HTML bar chart with
     error bars, light and dark.
4. Write README.md, METHODOLOGY.md (including threats to validity), UPSTREAM.md and CITATION.bib, plus
   one line linking plb2 from the top-level README.
5. Build and verify through marshal. Run ONE exclusive check job of the written programs against C;
   explain or fix any gap over 1.3x. Do a one-iteration smoke run of reproduce.zsh as a build job.
6. Grep that nothing outside `plb2/` is referenced. Commit without a trailer, push, and report READY.
