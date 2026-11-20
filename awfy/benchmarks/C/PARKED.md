# C column for AWFY: parked

This is work in progress. It has not been compiled, run or verified yet. It is parked while the work
concentrates on sysl against C++.

## Existing public C ports: none usable

`gh search repos "are we fast yet" --language c` finds one C port:
**rochus-keller/Are-we-fast-yet**, `C/`.

- **Licence:** MIT in each file header (Stefan Marr's, plus Rochus Keller's for the C99 port). The
  repository LICENSE.md is upstream's. Reuse is allowed.
- **Coverage:** all 14 benchmarks.
- **Does not build unmodified.** Apple clang 21.0.0 with `clang -O3 -std=c99 -w` stops with 13 errors
  of the kind `-Wincompatible-function-pointer-types`, in DeltaBlue, Havlak, Json, List, Permute,
  Queens, Storage and Towers. These are calls through mismatched function-pointer types, which are
  undefined behaviour. Its README says the code needs `-w` or `-fpermissive`.
- **Does not follow upstream's port.** It was "directly derived" from Rochus Keller's own C++ port,
  not from upstream's `benchmarks/C++`. It is pinned to upstream 770c6649 (2020), not f35aed0a.
  DeltaBlue uses tagged unions and Json uses vtables.
- Its own README reports Havlak and DeltaBlue 2 to 3 times slower than C++.

Verdict: rejected. Its build needs changes, and it is not a port of upstream's C++. The port here is
original, written for this benchmark.

## Done (in `src/`, mirroring upstream's `benchmarks/C++/src`)

- `benchmark.h`, `harness.c`. The harness follows upstream's `run.h` and `harness.cpp`: the same
  output lines, and inner iterations verified on every run. `benchmark()` returns a `Result` union,
  which stands in for `std::any`.
- `som/vector.h`, `som/set.h` and `som/dictionary.h` are typed macro modules (`DEFINE_VECTOR`,
  `DEFINE_VECTOR_OF_POINTERS`, `DEFINE_SET`, `DEFINE_IDENTITY_DICTIONARY`). Each one generates its
  struct and its `static inline` functions for one element type. This matches what the C++ templates
  do at run time: elements are stored inline and by value, and the code is monomorphic.
  - Dictionary entries and the dictionary itself keep the C++ virtual calls (`match`, the destructor,
    `newEntry`) through vtable pointers.
  - Closures are a function pointer plus a context pointer.
  - Upstream's quirks are kept: `atPut` reallocates whenever the index is past the size, `sort`'s
    `swap` exits, and `removeAll` reallocates.
- `som/random.h`, `som/error.h` (an error prints and exits), `memory/object_tracker.{h,c}`.
  - Every tracked struct starts with a `TrackedObject` whose `vt` points at the first member of the
    class's vtable struct. This is the CPython `PyObject` pattern.
- Benchmarks written: Bounce, List, Mandelbrot, NBody, Permute, Queens, Sieve, Storage, Towers,
  Richards, DeltaBlue, Havlak.
  - Storage keeps C++'s array cookie as a length header.
  - Sieve passes its array by value, as C++ does.
  - Richards' `dynamic_cast` becomes a vtable-pointer comparison, which is a checked downcast.
  - DeltaBlue has one `ConstraintVtbl` per concrete class, filled as C++ resolves the overrides.

## Left

1. **Json** (`json.c`)
   - Copy the literal at `C++/src/json.h` lines 12-451 byte for byte into `json_data.inc`, then check
     it with `diff`.
   - Planned representation: `_current` becomes an `int` (a char, or -1 for the empty string). Owned
     strings are `{char*, length}`. A name moves into the object instead of the C++ copy-then-destroy.
2. **CD** (`cd.c`)
   - A typed `RedBlackTree` macro or file for `<Vector2D, MotionVector*>`, `<Vector2D, bool>`,
     `<CallSign, Vector3D>` and `<CallSign, bool>`.
   - `std::optional` becomes a `{bool has, V value}` struct.
   - Vectors of Motion, Aircraft, Collision and CallSign hold their elements by value.
3. `build.sh`: `clang $OPT -ffp-contract=off -std=c17 -Wall -Wextra`, with `OPT` defaulting to
   config's `CPP_OPT` (`-O3 -flto -mcpu=native`). Then compile with no warnings.
4. Verify all 14 benchmarks. Run a leak check with `-fsanitize=address` or `leaks`.
5. Integration. The coordinator asked that C stay opt-in:
   - `LANGS=(${=LANGS:-sysl cpp})` in `scripts/config.zsh`.
   - A `c` case in `harness_of`.
   - A C block in `build.zsh`.
   - A column in `report.py` only when `c` is in `langs`.
6. A timing check of C against C++ through marshal (`--exclusive`). Explain each ratio above 1.3 or
   below 0.7.
7. `SOURCES.md` § C: "original, written for this benchmark", with the mapping table. Deviations to
   list:
   - plain indexing for `.at()`
   - `Result` for `std::any`
   - an `int32_t` in place of `std::any` in List's `Element`
   - the `dynamic_cast` mapping
   - the IdentitySet `contains` note
8. `METHODOLOGY.md`: add C to the language list.
