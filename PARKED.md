# PARKED: fastest-zig-odin-c3

Parked 2026-11-20 on the user's instruction (focus moved to AWFY). Branch `fastest-zig-odin-c3`,
worktree `/Users/ed/dev/sysl-lang/bench-fastest-zoc`, off `dev` 2446481.

## The rules this work follows (from the user, via the coordinator, in order of arrival)

1. The Game programs run **multi-threaded, as published**. README rule 1 is left alone; a METHODOLOGY
   agent rewrites the rules afterwards.
2. **No source changes to anything taken from elsewhere.** A published program is used byte for byte
   or passed over (reason recorded). Only build flags, paths and libraries may differ.
3. Inputs and outputs are **the Game's own sizes** and outputs.
4. Where no published program runs unmodified, **write one**, labelled "original, written for this
   benchmark", to the Game's rules, mirroring the Game's fastest C entry that builds here (the
   `fastest-c-rust` branch's `programs/<p>/c`): its decomposition, data layout, tricks and threading.
   Written well and fast. No cell empty.
5. **Prove it is competitive**: once everything verifies, ONE timing job comparing each written program
   against that C entry (`marshal run --exclusive --quiet-load auto --mem 8G --deadline 45m --label
   zoc-check`, only when `marshal ls -c` shows nothing running). More than ~1.3x C needs a reason,
   found and fixed or documented. Never make a rival slower.

## Done

All 30 cells are filled (`programs/*/{zig,odin,c3}/`). Provenance is in SOURCES.md, section
"Zig, Odin and C3" (sources searched, every candidate and why it was used or not, the cells table,
what each original does and which C entry it mirrors, toolchains, flags, licences).

- **Published, unmodified (6)**: Odin `binarytrees` (hanabi `binarytrees/1.odin`), Odin `nbody`
  (hanabi `nbody/1-i.odin`); C3 `mandelbrot`, `fasta`, `fannkuchredux` (`fannkuch-redux.c3`), `nbody`
  (`nbodies.c3`) from c3c `resources/examples`. File renamed only.
- **Original (24)**: all ten Zig programs (no hanabi Zig program builds on Zig 0.17.1); Odin
  spectralnorm, fannkuchredux, mandelbrot, fasta, knucleotide, revcomp, regexredux, pidigits; C3
  spectralnorm, binarytrees, knucleotide, revcomp, regexredux, pidigits. Each file's header says
  "Original, written for this benchmark" and names the C entry it mirrors.
- Threaded as the C entry is: spectralnorm, fannkuchredux, binarytrees, mandelbrot, knucleotide,
  revcomp, regexredux. Single-threaded as the C entry is: nbody, fasta, pidigits.
- `scripts/build.zsh`: Zig no longer gets `-fsingle-threaded`; Odin and C3 regex-redux link
  Homebrew's PCRE2 (`odin "-extra-linker-flags:-L$PCRE2/lib"`, `c3 "-L $PCRE2/lib -l pcre2-8"`).
- SOURCES.md: the old Odin/C3/Zig text in "Go and D", "Eiffel", the regex-redux and pidigits tables
  now points to the new section (headings "Go, D and Odin" and "C3, Eiffel" renamed).

## Verified

Marshal job 8167 (killed when parked, after this point): `scripts/build.zsh c zig odin c3` built
everything, and `scripts/run.zsh --verify zig odin c3` printed **ok for all 30** (the Game's output at
the small size, and C's hash at this suite's timed size). The Game-size comparison against the plain
C program had passed binarytrees (21) and fannkuchredux (12) for all three languages when it was
killed. Earlier probes (job 8126) checked the published programs at the Game's sizes: Odin
binarytrees 18 and 21, Odin nbody 50M, C3 nbodies 50M, fasta 25M, mandelbrot 6,000 and 16,000,
fannkuch 11 and 12: all match C. Revcomp originals were also checked on an input with irregular
line widths (the non-fast path) against C.

## Not done (next steps)

1. Re-run the Game-size check for the rest: `zsh <scratch>/verify.zsh` did it; the script is simple
   to recreate: build fasta 25M and 5M inputs with `build/fasta/c`; compare each Zig/Odin/C3 output
   with `build/<p>/c` at binarytrees 21, fannkuch 12, mandelbrot 16000, spectralnorm 5500, nbody 50M,
   fasta 25M, pidigits 10000, knucleotide and revcomp on fasta 25M, regexredux on fasta 5M. Run it
   through marshal at normal priority (`--kind build --mem 8G --deadline 1h --label fastest-zoc`).
2. The ONE timing job (rule 5 above): build the C entries from
   `/Users/ed/dev/sysl-lang/bench-fastest-c-rust/programs/<p>/c` with that branch's `C_FLAGS`
   (OpenMP via `-Xpreprocessor -fopenmp` + Homebrew libomp, APR for binarytrees, `-ffp-contract=off`
   for mandelbrot, `-pthread` for revcomp), then `hyperfine -N --warmup 1 --runs 5` each against the
   written Zig/Odin/C3 programs at the Game's sizes. A draft script was in the session scratchpad
   (`timing.zsh`); it is not in the repo.
3. Fix any written program over ~1.3x C, or document why. Candidates to watch: nbody originals are
   plain scalar (gcc-6 form; Zig's could use `@Vector` pair arithmetic); Odin knucleotide's built-in
   map cannot take gcc's hash; C3 binarytrees' arena adds a 16-byte header per node (32 B a node
   against APR's 16); spectralnorm originals are scalar (gcc-3 is scalar too).
4. AUDIT.md: add a "Zig, Odin and C3" section (not yet written) recording: the provenance rule; the
   removal of `-fsingle-threaded`; Odin and C3 regex-redux moved from their standard regex libraries
   to PCRE2's JIT (the Game's fastest entries' library); the passed-over sources and why; the timing
   results.
5. README (not this branch's to edit; tell the METHODOLOGY agent): rule 5's Zig flags still say
   `-fsingle-threaded`; "PCRE2 with its JIT for C, C++, Rust, Zig, Fortran and Go" now also covers
   Odin and C3; the single-thread wording.
6. Then report READY: branch and sha, per-cell provenance, verification counts, and
   `git -C /Users/ed/dev/sysl-lang/bench status --short` (empty).

## Findings

- **No published Zig program for these benchmarks builds on Zig 0.17.1**: hanabi's are written for
  Zig 0.14 (std.io/process APIs since removed). Running them unmodified would need Zig 0.14.1, a
  toolchain choice outside "flags, paths and libraries": a question for the user if wanted.
- **tiehuis/zig-benchmarks-game has no licence** and may not be copied; four hanabi Zig files say
  they are taken from it.
- **c3c's `spectralnorm.c3` example is wrong** (prints 1.259503018 for 100; its A-transpose product
  indexes A) and stores the whole matrix.
- hanabi's Odin `mandelbrot/1.odin` and the Zig `mandelbrot/1.zig` print an MD5 of the image and use
  `x*(2/size)` coordinates; Odin `knucleotide/1.odin` is 16-threaded and re-encodes each k-mer.
- The C entries that build on arm64 (fastest-c-rust) are not always the Game's fastest: the fastest
  nbody (`gcc-9`), spectralnorm (`gcc-6`), fannkuch (`gcc-6`), mandelbrot (`gcc-6`) and revcomp
  (`gcc-7`) use x86 intrinsics.
