# Rust port of AWFY: parked (work in progress, never built)

Parked 2026-11-20 at the coordinator's request: the track is focusing on sysl vs C++, and the Rust
column waits for a later release. Nothing here has been compiled yet; nothing is hooked into the
scripts.

## Provenance decision

Searched GitHub (`gh search repos "are we fast yet" rust`, `"awfy rust"`, `"are-we-fast-yet"`, and
code search for Rust `DeltaBlue`/`Havlak`). No standalone public Rust port exists. Two by-products
of other languages' benchmark folders were found and rejected:

- `larrydewey/Resid` `bench/v2/t1-awfy/rust` (MIT, 4 stars, pushed the day it was found): covers
  all 14, but Richards replaces the task closures with an enum dispatch over index arenas, so it does
  not follow upstream's structure; it is also a moving target inside another project.
- `icantcodefyi/sakuralang` `bench/programs/awfy_havlak/rust`: Havlak only, arena indices.

So the port is original, written for this benchmark, from upstream C++ at f35aed0a.

## Done (written, not compiled)

`Cargo.toml` (release: opt 3, fat LTO, codegen-units 1, panic abort), `.cargo/config.toml`
(`target-cpu=native`), `src/main.rs` (harness + run.h, upstream's output format),
`benchmark.rs` (associated `Result` type instead of `std::any`; object-safe `Runnable` for the
harness), `som/` (Vector, Set/IdentitySet, IdentityDictionary, Random, with C++'s growth policy and
quicksort), `memory.rs` (the two trackers below), and the benchmarks Bounce, List, Mandelbrot,
NBody, Permute, Queens, Sieve, Storage, Towers, Richards, Json (+ `json_data.rs`, Java line 39),
DeltaBlue.

Allocation policy: every C++ `new` is one `Box` (or `Box<[T]>`), so the allocation count matches
C++; known extras are Rust `String`s where libc++ uses the small-string buffer (Json), and freeing
the red-black node `remove` unlinks, which C++ leaks.

## Left

1. Write `cd.rs` (red-black tree with parent pointers: planned as `*mut Node` inside one
   encapsulated module, per-node `Box::into_raw`, freed from the root on drop, as C++) and
   `havlak.rs` (planned: basic blocks and loops by index, `UnionFindNode` parent by index,
   `IdentityDictionary<BasicBlock, i32>` keyed by `&BasicBlock` from the CFG; `RefCell<Set>` per
   `nonBackPreds` entry because `x != w` always holds, so the borrows never conflict).
2. Add `mod json_data;` to `main.rs`, remove the placeholder `unused_strength_operations` at the end
   of `deltablue.rs`, build, fix compile errors, `cargo generate-lockfile` (CARGO_HOME under the
   worktree's `build/`), commit `Cargo.lock`.
3. Verify 14/14 at timed sizes through marshal (`--kind build --mem 8G --deadline 1h`).
4. Integration, opt-in only (coordinator): `reproduce.zsh` must still default to sysl + C++. Make
   `LANGS` in `scripts/config.zsh` overridable (`LANGS=(${=LANGS:-sysl cpp})`), add a `rust` case to
   `harness_of`, a separate Rust block in `build.zsh`, a Rust line in `check-upstream.zsh` comparing
   `src/json_data.rs` line 4 with Java line 39, and a generic extra column in `report.py`.
5. One exclusive timing job Rust vs C++; investigate any benchmark over ~1.3x.
6. `SOURCES.md` § Rust (every deviation with its guideline) and METHODOLOGY.md's language list.

## Probe: a `dyn` closure cannot live in a self-referential arena

Rust's drop checker assumes a trait object's destructor may read any lifetime in its type, so a
`Box<dyn Fn() + 'a>` (or even `Box<dyn Fn(&'a Scheduler<'a>)>`, with no captures) stored in a
`RefCell<Vec<Box<T>>>` arena whose objects reference each other with `'a` fails with E0597
("`tr` dropped here while still borrowed ... runs the destructor for type `Tracker<Obj<'_>>`").
Concrete types with only references, `Cell`s and `Vec`s pass. Hence two trackers in `memory.rs`:
`Tracker<T>` (typed, runs destructors; DeltaBlue) and `ObjectTracker` (any type with no destructor,
asserted at compile time, frees memory only; Richards, whose closures capture `&Scheduler` as C++'s
capture `this` and are called through `&dyn Fn`).

## `unsafe` so far

`memory.rs`: one block in `Tracker::track` (reference into a `Box` the tracker owns), one in
`ObjectTracker::track` (reference from `Box::into_raw`), one in `ObjectTracker::drop` (`dealloc` of
destructor-free objects). Each carries its SAFETY argument. CD's tree will add more.
