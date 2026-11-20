# PARKED: mt-sysl-b (multi-threaded sysl nbody, pidigits, regexredux, revcomp, spectralnorm)

Parked 2026-11-20 on the user's instruction (focus on AWFY). Worktree
`/Users/ed/dev/sysl-lang/bench-mt-sysl-b`, branch `mt-sysl-b` off origin/dev `2446481`, pushed.

## Done (commit ba14ad2)

Both columns of all five programs rewritten for sysl 0.12.0; decompositions follow the Game's
fastest C/C++/Rust entries (from its `performance/<program>.html`, 2026-11-20). The full account is
SOURCES.md § "sysl multi-threaded (nbody, pidigits, regexredux, revcomp, spectralnorm)".

- **nbody**: one thread in both (gcc-9, g++-0, Rust-9 are all single-threaded). Tuned is now gcc-9's
  form: pairwise differences into arrays, magnitudes two at a time in `<2>real`, exact sqrt.
- **pidigits**: one thread in both (all fastest entries are). Both now on GMP through
  `sysl-lang/gmp` 0.1.0 (`sysl.hocon` + `sysl.sum` copied into each column; build.zsh picks them up
  with no change). Idiomatic: operators. Tuned: in place, two divisions. `sysl-tuned-gmp/` is now
  unused (not deleted: outside the brief's edit scope).
- **spectralnorm**: idiomatic opens a `scope` per product, one band of rows per `cpu_count()`.
  Tuned: persistent threads + `barrier`, gcc-6's 4x4 tiles with one common denominator per row.
- **revcomp**: idiomatic bands of output lines on scoped threads into an output array, one write.
  Tuned: gcc-7's 8,192-line chunks claimed from a `&sync Atomic[usize]`, 16-byte shuffle + two
  `lookup` tables, `realloc` input, one write.
- **regexredux**: Rust-7's decomposition (substitution chain on one thread beside nine count
  threads). Idiomatic on `sysl.regex`, sequence shared once as a `&sync Sequence`; still DNF at the
  timed size (FINDINGS §9). Tuned: PCRE2 JIT, per-thread matcher, in-place substitutions.
- `expected/game/`: the Game's published outputs at its sizes (nbody 50,000,000, spectralnorm 5500,
  regexredux on fasta 5,000,000), copied from its program pages. pidigits and revcomp are truncated
  on those pages, so they are not there.

## Verified (all through marshal, normal priority)

- `scripts/run.zsh --verify` on both columns of all five: 10/10 ok (regexredux idiomatic at the small
  size only, its existing DNF).
- Against `expected/game/`: nbody and spectralnorm both columns, regexredux tuned at fasta 5,000,000
  (`build/fasta/c 5000000`): 5/5 ok.

## In progress (not done)

- The one CPU-vs-wall sanity job was written but never ran (killed while waiting for a quiet
  machine). Script: `/Users/ed/.claude/tmp/claude-501/-Users-ed-dev-sysl-lang/110d1333-fbfb-441f-a9fc-bbf4ec24eda1/scratchpad/cpu.zsh`
  (may be gone; it is `/usr/bin/time -p` of each binary at its timed size, regexredux idiomatic at
  fasta 100,000). Run it only when `marshal ls -c` shows nothing running, as
  `marshal run --exclusive --quiet-load auto --mem 8G --deadline 20m`.

## Next steps

1. Run the CPU/wall job; confirm spectralnorm, revcomp and regexredux use more than one core (no
   CPU/wall ratio was measured yet).
2. Decide with the director whether `programs/pidigits/sysl-tuned-gmp/` is removed.
3. Merge origin/dev in, re-verify, report READY (branch, sha, file list).
4. Not mine but noted: `scripts/lib.zsh` still times regexredux on fasta 10,000,000, where the Game
   uses 5,000,000, and the Game names its revcomp input `revcomp-input100000001.txt`.

## Findings (no Rule 9 stop)

No Rule 9 report: nothing needed a workaround. Smaller findings:

- **Diagnostic lands in library code**: a closure handed to `Scope.spawn` whose body failed to type
  (`tally[i] = <usize>` into `[]int`) was first reported as `cannot infer the type argument 'T' of
  'None' here` at `library/sysl/threads/scope.sysl:46:47`, plus `cannot infer the type argument 'R'
  of 'sysl.threads.Scope.spawn'`, a cascade from `var counts = [0; variants.len]` being refused.
  Fixing the array alone then gave the right message (`cannot assign usize to this element of type
  int`). An error inside the standard library for a user's mistake is worth a compiler item.
- **`[0; variants.len]`** with `variants` a module `val` over a nine-element literal is refused as
  not constant; `var counts: []int = [0; variants.len]` (runtime storage) is the documented form, so
  not a gap, but a `val` array literal's `.len` could fold.
- The `Scope.spawn` docstring (`scope.sysl`) says a captured `string` is refused; memory.md § "A
  string crosses into a shared object" shows `s.spawn` capturing one and copying it. The docstring is
  stale.
- sysl has no reciprocal-square-root or reciprocal estimate (`frsqrte`/`frecpe`) for vectors; gcc-9
  (nbody) and gcc-6 (spectralnorm) use x86's. Not used here: exact sqrt/divide instead (AArch64's
  estimate is ~8 bits and needs an extra refinement). A possible vectors.md item, not a blocker.
