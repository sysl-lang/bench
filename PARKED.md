# PARKED: fastest Ada, Fortran and Swift entries (branch `fastest-ada-fortran-swift`)

Parked 2026-11-20 on the user's instruction (focus moved to AWFY). Worktree:
`/Users/ed/dev/sysl-lang/bench-fastest-afs`, made from origin/dev 2446481.

## The rules this work follows (from the user, via the coordinator, in order of arrival)

1. Each Ada, Fortran and Swift program is the Game's fastest entry, run **multi-threaded as the Game
   runs it, with NO source change at all** (not sizes, output, threads or intrinsics). An entry that
   needs a change is skipped for the next fastest that runs as published; each skip is recorded.
2. Build flags, paths and installed libraries are allowed, and disclosed. Flags follow each entry's
   Game build line mapped to this machine.
3. Where a language has no Game entry that runs unmodified, write one, "original, written for this
   benchmark", mirroring the Game's fastest C entry (its decomposition, threading, tricks), fast
   enough to stand scrutiny (within ~1.3x of that C entry), with every technique stated in SOURCES.md.
4. Fortran: Intel ifx (the Game's) was checked for macOS; gfortran and flang both built and timed,
   and the column's compiler chosen by geomean.
5. README rule 1 is not to be edited; a METHODOLOGY agent rewrites the rules afterwards.

"Fastest" is ranked by the Game's **elapsed** seconds (its own sort, and what the harness times now
that the programs run multi-threaded). The original brief said CPU seconds, written when everything was
single-threaded; the coordinator has not been asked to confirm this switch. **Confirm it.**

## Done (committed on this branch)

Game measurements fetched 2026-11-20 from `measurements/{gnat,ifx,swift}.html` (largest N);
sources from the Game's `download/benchmarksgame-sourcecode.zip`. Ada entries are gnatchop's output
(several files per directory), otherwise byte-identical to the archive.

| program | Ada (GNAT) | Fortran | Swift |
|---|---|---|---|
| binarytrees | `gnat-3` (11.26 s elapsed) | `ifc-2` (APR pools, OpenMP) | `swift-4` |
| fannkuchredux | `gnat-3` (tasks) | `ifc-3` (OpenMP) | `swift-8` |
| fasta | `gnat-5` | `ifc-4` | `swift-3` (Dispatch) |
| knucleotide | `gnat-2` (tasks; GNAT.HTable) | **original** (see below) | `swift-2` |
| mandelbrot | `gnat-3` (33 tasks) | `ifc-6` (OpenMP) | `swift-7` (SIMD8, Dispatch) |
| nbody | `gnat-3` | `ifc-5` | `swift-3` |
| pidigits | `gnat` (`-1`) | `ifc-4` | `swift-2` (+ `module.modulemap`, `gmp-shim.h`, as before) |
| regexredux | `gnat-5` (GNAT.Spitbol patterns, tasks) | **original** (see below) | `swift-4` |
| revcomp | `gnat-2` | `ifc-2` | `swift` (`-1`, Dispatch) |
| spectralnorm | `gnat-3` (tasks) | `ifc-3` (OpenMP) | `swift-8` |

**Skipped (fastest entry needs a source change here):**
- Ada binarytrees `gnat-4` (4.16 s): raises Constraint_Error at the verification depth 10 (its 5
  workers outnumber the 4 depth iterations; fine at 18 and 21). Next: `gnat-3`.
- Ada spectralnorm `gnat-4` (0.77 s): imports x86 intrinsics `__builtin_ia32_divpd/addpd/mulpd`,
  which GCC has only on x86. Next: `gnat-3`.
- Ada pidigits `gnat-2` (0.745 s): imports `printf` as a non-variadic C function; arm64 macOS passes
  variadic arguments on the stack, so it prints garbage. Next: `gnat` (`-1`, 4.49 s on the Game,
  verified at 27 and 10,000 digits).
- Fortran revcomp `ifc` (`-1`, 3.35 s): reopens the preconnected units 5/6 for stream access, which
  gfortran and flang refuse at run time. Next: `ifc-2`.
- Fortran regexredux `ifc` (the only Fortran entry): the same reopen. Written instead (below).
- Swift fannkuchredux `swift-3` (8.2 s) and spectralnorm `swift-3` (1.45 s): `import Glibc`, which
  macOS lacks. Next: `swift-8` for both.
- Swift fasta `swift-1`/`-8`, regexredux `-1`/`-2`, binarytrees `-1`, mandelbrot others: slower on
  elapsed, not skipped for a reason.

**Original programs (Fortran), each mirroring the Game's fastest C entry:**
- `programs/knucleotide/fortran/knucleotide.f90`: after `knucleotide.gcc` (Jeremy Zerfas): 2k-bit codes
  rolled per base, open-addressing table of int64 keys / int32 counts with C's hash `key ^ key>>7`,
  the seven tables in `!$omp parallel sections`, text printed in order. The table is **ffhash**
  (github.com/jannisteunissen/ffhash at c11397129737b0f7791f2b9485babf9a0321eb37, "similar to khash
  in C", khash-style MIT licence), vendored as `ffhash_inc.f90` + `LICENSE-ffhash`, instantiated with
  the preprocessor (`-cpp`) as C includes `khash.h`. The fortran-stdlib hash map it used before
  allocated per lookup (about 16x C); ffhash brought it level with C.
- `programs/regexredux/fortran/regexredux.f90`: the Game's `regexredux.ifc` (a translation of C's
  `gcc-5`, PCRE2 JIT, OpenMP) with standard input read by POSIX `read(2)`, and the `PCRE2_SIZE`
  arguments declared `c_size_t` (the archive passes `c_int`).

**Build lines** (`scripts/build.zsh`): `HOST_CPU` read from `clang -mcpu=native -###` (apple-m4;
GCC's own `-mcpu=native` reads apple-m1). Swift `-Ounchecked -wmo -target-cpu $HOST_CPU` (the
Game's line). Ada `gnatmake -O3 -fomit-frame-pointer -mcpu=$HOST_CPU -gnatn2 -f` (the Game's line;
`-gnatp` dropped, so checks are on except where an entry suppresses them). Fortran `$FORTRAN -O3
-mcpu=$HOST_CPU -flto` (+`-fopenmp` for binarytrees, fannkuchredux, mandelbrot, spectralnorm,
knucleotide, regexredux; `-ffp-contract=off` for mandelbrot, whose `ifc-6` output flips boundary
pixels when fused, the Game's ivybridge having no FMA; `-cpp` for knucleotide). APR (`brew` apr,
keg-only) linked for Ada and Fortran binarytrees; PCRE2 for Fortran regexredux. `scripts/lib.zsh`:
`FORTRAN` (default flang, exported) and an `ABSENT` table (empty now) that build/run skip.
`scripts/report.py`: the Swift, Ada, Fortran flag descriptions and the Fortran version line.

## Verified

- Marshal job 8157 (the picks above, gfortran as the Fortran compiler): **30 of 30** (swift, ada,
  fortran x 10 programs) match the Game's output at the small size and C's hash at the timed size.
  The timing job also checked all ten Fortran programs under both compilers at the timed size: all ok
  except flang regexredux, since fixed.
- After 8157, changed: Fortran `regexredux.f90` (read(2)) and the default compiler (flang). Checked
  by hand only: regexredux with gfortran and flang at the small size (file and pipe) and the 10 MB
  hash. **The final marshal verify (job 8170, flang then gfortran) was killed when parking.**

## Timing (marshal job, `--exclusive`, hyperfine -N, 5 runs, median wall s; afs-check)

| program | gfortran | flang | C (OpenMP, Game entry) |
|---|---|---|---|
| binarytrees | 0.028 | 0.074 | |
| fannkuchredux | 0.172 | 0.112 | |
| fasta | 1.439 | 0.597 | |
| knucleotide (original) | 0.314 | 0.396 | 0.359 (`knucleotide.gcc`) |
| mandelbrot | 0.089 | 0.224 | |
| nbody | 1.722 | 1.250 | |
| pidigits | 0.248 | 0.245 | |
| regexredux (original) | 0.786 | WRONG then (flang misread /dev/stdin; fixed since by read(2)) | 0.742 (`gcc-5`) |
| revcomp | 3.779 | 0.898 | |
| spectralnorm | 0.052 | 0.056 | |
| **geomean of 9 (no regexredux)** | **0.2934** | **0.2667** | |

flang chosen by geomean (9% lower). The written programs are 0.87x-1.10x (knucleotide) and 1.06x
(regexredux) of the C entries they mirror. The sizes here are the suite's (lib.zsh), several below the
Game's, so binarytrees, mandelbrot and spectralnorm run in tens of milliseconds: start-up and thread
spin-up weigh heavily at these sizes.

## Next steps

1. Rerun the final verify: `caffeinate -dimsu marshal run --kind build --mem 8G --deadline 1h --dir
   /Users/ed/dev/sysl-lang/bench-fastest-afs --label fastest-afs -- zsh -c "zsh scripts/build.zsh
   swift ada fortran && zsh scripts/run.zsh --verify swift ada fortran && FORTRAN=gfortran zsh
   scripts/build.zsh fortran && FORTRAN=gfortran zsh scripts/run.zsh --verify fortran"` (build/
   already holds the C inputs; on a fresh build/, add `c` to the first build).
2. Write SOURCES.md's Ada, Fortran and Swift sections (and their rows in the shared Programs,
   regex-redux and pidigits tables): each entry, its Game elapsed/CPU, the skips above, the build
   lines, the ifx finding, the two originals and every technique in them (above). Not yet done:
   SOURCES.md and AUDIT.md still describe the old ports.
3. AUDIT.md: an "Ada, Fortran, Swift" section like § Go: the old columns were ports, not the Game's
   entries; the skips; flang's choice with the numbers above; the FMA flag; checks now on for Ada
   (no `-gnatp`) and off for Swift (`-Ounchecked`).
4. Tell the coordinator README text now contradicts the code (rules 1, 3, 5, 6; the
   fortran-stdlib paragraph in rule 3) — the METHODOLOGY agent's job, not this branch's.
5. Delete scratch: `/Users/ed/.claude/tmp/claude-501/-Users-ed-dev-sysl-lang/110d1333-fbfb-441f-a9fc-bbf4ec24eda1/scratchpad/`
   (archive zip, trial builds, `ftime.zsh` and its JSON).

## Findings

- **Intel ifx has no macOS release**: Intel's get-started guide 2024.2 ("Starting with the 2024.0
  release, macOS is not supported by the ifx compiler",
  intel.com/content/www/us/en/docs/fortran-compiler/get-started-guide/2024-2/get-started-on-macos.html)
  and the 2024 system requirements ("Intel oneAPI HPC Toolkit for macOS on x86 is discontinued in the
  2024.0 release ... This includes Intel Fortran Compiler Classic (ifort)",
  intel.com/content/www/us/en/developer/articles/system-requirements/fortran-compiler/2024.html).
  Neither ever ran natively on Apple Silicon.
- Ada `fasta.gnat-5` and `mandelbrot.gnat-3` open `/dev/stdout` as a file: with stdout redirected to
  a regular file macOS refuses it (USE_ERROR), and mandelbrot then hangs (its tasks wait forever).
  Through a pipe or hyperfine's null output they work, which is how the harness runs them.
- flang 23 reading `/dev/stdin` as a stream reported one byte more than the file held.
- `regexredux.ifc` passes `PCRE2_SIZE` (size_t) arguments as `c_int`; on arm64 the upper half of the
  register is not defined by the callee's contract, so it is declared `c_size_t` here.
