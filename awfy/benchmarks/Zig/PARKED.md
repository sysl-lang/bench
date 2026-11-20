# Zig port of AWFY: parked

Parked on 2026-11-20 while the track focuses on sysl against C++. Nothing here is hooked into
`reproduce.zsh` or the scripts yet.

## Provenance

No public Zig port of AWFY was usable. Upstream (smarr/are-we-fast-yet) has none. The only one found
(`larrydewey/Resid`, `bench/v2/t1-awfy/zig`, MIT) does not build unmodified on Zig 0.17.1
(`.{0} ** 32` is refused). It also uses arenas where the C++ port frees objects one by one. This port is
therefore original, written for this benchmark from the C++ port at upstream f35aed0a.

## Done

- All 14 benchmarks are ported from the C++ port, file for file: `harness.zig`, `run.zig`, `benchmark.zig`,
  `mem.zig` (the allocator and `object_tracker`) and `som/` (Vector, Dictionary, Set, Random).
- The Debug build (`zig build-exe -O debug harness.zig`) compiles. All 14 benchmarks pass their own
  verification at small sizes, with no leaks reported by `DebugAllocator`. The sizes were Bounce, Havlak,
  Json, List, Mandelbrot, NBody, Permute, Queens, Richards, Sieve, Storage and Towers at 1, CD at 10 and
  DeltaBlue at 20.
- `json_data.zig` is generated from json.h's `rapBenchmarkMinified`. The generator is a 15-line C++
  program that includes json.h and writes the string with `"` and `\` escaped.
- Dispatch choices:
  - The Benchmark interface and DeltaBlue's constraint hierarchy use vtables (a function-pointer table
    plus `@fieldParentPtr`), which keeps C++'s virtual calls.
  - Richards' task closures are a context (the scheduler) plus a function pointer, and data records are
    `*anyopaque`, which keeps the `std::function` indirect call.
  - Json values are a kind tag plus `@fieldParentPtr`, the `std.Build.Step` pattern. Their virtual
    methods are only type tests, and each node is still its own allocation.
  - Collection `forEach`/`hasSome` take a context plus a comptime function, as `std.sort` does.
  - Dictionary `Entry::match` is not virtual here, because C++'s override has an identical body.
- Allocation goes through `mem.gpa`, which is Zig's own default from start.zig: libc malloc when libc is
  linked (macOS), `smp_allocator` otherwise. A C++ exception that nothing catches is a `@panic`.
- Json strings borrow from the constant input unless they contain an escape (std.json's
  `.alloc_if_needed`). C++ copies them into SSO `std::string`s. The document has no escapes.

## Left

1. Build with `-O fast -mcpu=native` (0.17's name for
   ReleaseFast) through marshal and verify 14/14 at the timed sizes (config.zsh INNER).
2. CD calls `@cos`/`@sin`. If the collision counts differ from libm's, call libc `cos`/`sin` as C++ does.
3. Run the exclusive timing check of Zig against C++. Explain or fix any benchmark above ~1.3x.
4. Integrate as an opt-in column: config.zsh keeps `LANGS=(sysl cpp)` by default and allows an override
   (for example `LANGS="sysl cpp zig"`). Add `harness_of zig` and a Zig step in build.zsh. report.py
   gains `LANG_NAMES["zig"]` and an extra-languages table. Keep the edits small; the Rust and fixer
   agents touch the same scripts.
5. Write SOURCES.md § Zig ("original, written for this benchmark", with every deviation: ReleaseFast
   drops the bounds checks C++'s `.at()` keeps; List's value is `i32`, not `std::any`; dead C++ null
   checks dropped where the types forbid null; `IdentitySet` is `Set` because C++'s `contains` hides
   rather than overrides). Add METHODOLOGY.md's language entry.
