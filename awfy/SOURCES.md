# Where every file comes from, and how the sysl port differs from upstream's

Upstream is <https://github.com/smarr/are-we-fast-yet> at commit
`f35aed0a61171594804a44efe9d75f1f35360700` (2026-11-15), MIT ([LICENSE-awfy.md](LICENSE-awfy.md)).

| path | origin |
|---|---|
| `benchmarks/C++/`, `benchmarks/script.inc`, `rebench.conf` | upstream, byte for byte (`scripts/check-upstream.zsh`) |
| `LICENSE-awfy.md`, `CITATION.bib` | upstream `LICENSE.md`, `CITATION.bib`, byte for byte |
| `benchmarks/sysl/` | this port, from upstream's C++ and Java ports (below) |
| `benchmarks/sysl/json_data.sysl` | the document of upstream `benchmarks/Java/src/Json.java` line 39, character for character (checked by `scripts/check-upstream.zsh`) |
| `benchmarks/Zig/` | the Zig port, written here from upstream's C++ port (below, "The Zig port") |
| `benchmarks/Zig/json_data.zig` | json.h's `rapBenchmarkMinified`, written out by a 15-line C++ program that includes json.h and escapes `"` and `\` |
| `benchmarks/C/` | the C port, written here from upstream's C++ port (below, "The C port") |
| `benchmarks/C/src/json_data.inc` | upstream `benchmarks/C++/src/json.h` lines 13-451, byte for byte (checked by `scripts/check-upstream.zsh`) |
| `benchmarks/Rust/` | the Rust port, written here from upstream's C++ port (below, "The Rust port") |
| `benchmarks/Rust/src/json_data.rs` | the document of upstream `benchmarks/Java/src/Json.java` line 39, character for character (checked by `scripts/check-upstream.zsh`) |
| `reproduce.zsh`, `scripts/`, `README.md`, `METHODOLOGY.md`, this file | written here |

Everything the track needs is inside `awfy/`; upstream is fetched into `build/upstream` (ignored by
git) only to check the copies and to build the C++ harness where upstream's `build.sh` expects to run.

## The rules the port follows

Upstream's [guidelines](https://github.com/smarr/are-we-fast-yet/blob/f35aed0a61171594804a44efe9d75f1f35360700/docs/guidelines.md)
(cited below as **G**, by section) and its
[core language](https://github.com/smarr/are-we-fast-yet/blob/f35aed0a61171594804a44efe9d75f1f35360700/docs/core-language.md)
(**CL**):

- **G "As Identical as Possible"** and **G "Guidelines for New Languages"** ("Identical code structure
  is more important than 100% idiomatic code ... the same structure of methods and similar naming"):
  every class, method and loop of the C++ and Java ports has its counterpart, in the same order, under
  the same name in `snake_case`. A C++ instance method is a sysl method (`*self`); a C++ `static`
  member function is a module-level function of the same file (file-`private` where C++'s is private).
  Iteration over a collection is its `for_each` with a closure.
- **CL "Excluded Abstractions"**: no built-in collections (the suite's own `Vector`, `Set`,
  `IdentitySet`, `IdentityDictionary` and `Random` are in `som/`, over fixed-size storage they grow
  themselves, never sysl's `Buf` or `Map`); no identity hash; no `break` or `continue` in a
  benchmark's loops; a `return` from a loop only inside an `if`; no character type (the current
  character of Json is a one-byte string).
- **G "Idiomatic Use of Language"** and **G "Well-typed Behavior"**: written as the org writes sysl
  (inferred types, `&T` for shared objects, `Option` where C++ has a null pointer, a trait where C++
  has a virtual method). Where idiom and identity disagree, identity wins, as G says.
- **G "C++", "Explicit Memory Management Rules"**: no leaks. sysl counts references, so a cycle needs
  breaking: each owner that C++ frees in a destructor breaks its graph's cycles in a `Drop`. A
  counted-heap build (`SYSL_COUNT_ALLOCS=1`) ends every benchmark with a net count of zero
  (`scripts/leaks.zsh`; the same build reports a deliberately leaked cycle, so the check can fail).
- **Built-in verification**: the harness prints `Benchmark failed with incorrect result` and exits 1
  when a check fails, as upstream's harness does; `scripts/verify.zsh` runs every benchmark once at
  its timed size before any timing.

## Every structural difference, and why

Each entry names the guideline that allows it or the language fact that forces it. The work each
benchmark does is the same as C++'s; where sysl does more (reference counting, heap allocation), it
says so.

### Throughout

- **A class hierarchy becomes a trait or composition.** sysl has no inheritance. A virtual method is a
  trait member (`Benchmark`, `JsonValue`, DeltaBlue's `AbstractConstraint`); state a base class holds
  is a field holding a struct of it (Richards' `TaskControlBlock.state: TaskState`; DeltaBlue's
  `UnaryConstraint` and `BinaryConstraint` halves). Polymorphic calls stay polymorphic: a trait object
  (`&AbstractConstraint`, `&JsonValue`) is called through its table, as C++'s virtual call is. (CL
  "Required Abstractions": "polymorphic methods on user-defined classes/objects/types".)
- **A null pointer is `Option`.** `NO_WORK`, `NO_TASK` and every nullable link are `None`; a loop over a
  link is `while link is Some(n)`. G "Idiomatic Use" gives exactly this kind of difference as its
  example (`if node` in Ruby). Small helpers some files add for it (CD's `holds`, `is_black`) are the
  null test C++ writes inline.
- **A shared object is `&T`, a small value is `T`**, as C++ separates objects it allocates with `new`
  from its value classes (CD's vectors, `CallSign`, `Motion`; NBody's `Body`). G "C++" allows stack
  allocation "where natural"; sysl heap-allocates some objects C++ keeps on the stack (CD's per-frame
  `motions`, `seen`, `to_remove` and voxel map): more work for sysl, not less.
- **Freeing.** C++ deletes; sysl frees by count, and breaks cycles in a `Drop` where C++ has a
  destructor (G "Memory Management Strategies Per Benchmarks").
- **An exception is a `panic`.** C++ and Java throw an `Error` nothing catches; sysl stops the program.
- **Closures** passed to `for_each`, `has_some` and the like are sysl's ordinary closure parameters
  (`f: E -> unit`), which are generic: each call site gets its own copy. C++ passes a `std::function`,
  Java a lambda the JIT inlines. Both are the language's idiomatic way to take a closure (G
  "Idiomatic Use"; G "As Identical as Possible" wants `forEach` with a closure because it "exercises
  the compiler's abilities to optimize closures"). A closure that is stored (Richards' task
  functions) is a `&Fn`, as C++'s `std::function` member is. Upstream's Crystal port is the precedent:
  it takes `&block` and calls it with `yield` (`benchmarks/Crystal/som.cr:100`), inlined at each call
  site as sysl's is. METHODOLOGY.md, section 9, lists it with its measured size: the `std::function`
  costs C++ 25% on Havlak and 6.6% on DeltaBlue.
- **Renamed words.** Where a C++ or Java name is a sysl keyword it is renamed: Havlak's `type` is
  `types` and `loop` is `found_loop`; Json's `null` flag is `literal_null` (and its siblings
  `literal_true`, `literal_false`). Where C++ overloads `verify_result` with a second, private
  signature (Mandelbrot, NBody, Havlak, CD), sysl refuses a member that collides with a trait member,
  so the private one is named for its benchmark (`verify_mandelbrot`, ...).

### Harness: `harness.sysl`, `run.sysl`, `benchmark.sysl`

- `Benchmark.benchmark()` answers an associated type `Result` instead of C++'s `std::any` or Java's
  `Object`: sysl has no top type, and G "Well-typed Behavior" asks for well-typed values. A benchmark
  that overrides `inner_benchmark_loop` declares `Result = bool` and panics in the two members it
  never calls, as C++'s "Should never be reached".
- `Run` selects the benchmark by name with a `match` (G "Harness": "dynamically selects benchmark to
  execute based on arguments") and runs it through a generic `do_runs`, because a trait with an
  associated type is not a trait object. So `benchmark()` and `verify_result()` are direct calls
  where C++ makes two virtual calls per inner iteration. METHODOLOGY.md lists it; it is one call
  against an iteration's whole work.
- The output lines are upstream's, character for character. Time is `sysl.time.monotonic()` in
  microseconds, as C++'s `high_resolution_clock`.

### `som/`

- **`Vector`**: storage of `[]E` made by `slot_storage`, so the room past the last element holds
  nothing, as C++'s uninitialised `new E[n]` and Java's `null`s; initial size 10, doubling, as
  upstream. `at`, `first`, `remove_first` and `get_one` answer `Option[E]` where C++ answers a pointer
  or `nullptr`. `at_put` past the end cannot leave a gap (that slot would hold no element) and traps;
  no benchmark stores past the end. `remove` takes the comparison as a parameter, since the elements
  may be values (`==`) or objects (`===`); only DeltaBlue calls it, with `===`, which is C++'s pointer
  `==`. `remove_all` allocates new storage of the same size, as C++ and Java do. `swap`, which C++
  leaves unimplemented, is Java's.
- **`IdentityDictionary`** is upstream's chained hash table with its resize and bucket split. Keys are
  `&K` compared with `===`, hashed by the `CustomHash` trait, as upstream's. Upstream's equality
  `Dictionary`, of which `IdentityDictionary` is a subclass, is used by no benchmark and is not ported.
- **`Set`** compares with `==` (C++: `==` on `int32_t`, `equal()` on pointers); **`IdentitySet`** holds
  `&E` and compares with `===`.
- **`Random`** is upstream's.

### Micro benchmarks

- **Bounce**: the balls are a `[100]Ball` of values, as C++'s `std::array<Ball, 100>`, walked by index
  because a sysl `for` over an array binds a copy and the balls are written (C++ binds `auto&`).
- **List**: `Element.value` is an `int`, where C++ has `std::any` and Java `Object`: sysl has no top
  type, and only ints are stored (G "Well-typed Behavior"). The value is never read.
- **Mandelbrot**, **NBody**: as upstream; the private `verify_result` overloads are renamed (above).
  NBody's `NBodySystem` holds C++'s `bodies_size` field (`_bodiesSize`, `nbody.h:96`), and every loop
  runs to it, not to the array's length.
- **Permute**, **Queens**: the arrays are `[]int` and `[]bool` made per run, as C++'s `new[]`.
- **Sieve**: as C++: the flags are a `[5000]bool` zeroed, then filled with `true` (`fill`, as C++'s
  `std::fill_n`), and passed **by value**, so `sieve` works on its own copy as it does on C++'s
  `std::array` parameter.
- **Storage**: an `ArrayTree` holds a `[]ArrayTree`, as C++.
- **Towers**: `piles` is a `[3]Option[&TowersDisk]`, as C++'s `std::array<TowersDisk*, 3>`.

### Macro benchmarks

- **CD**: `RedBlackTree[K: CompareTo, V]` is generic over a key trait, as C++'s template over
  `compareTo`. Nodes hold a strong parent link; the tree's `Drop` clears the parent links, as C++'s
  destructor deletes from the root. `put` calls `tree_insert`, which answers an `InsertResult`, as
  C++. `forEach` hands the closure an `Entry` value. `InsertResult.old_value` is an `Option[V]` where
  C++ default-constructs a `V()` it never reads.
- **DeltaBlue**: constraints are `&AbstractConstraint` trait objects compared with `===` (sysl 0.12.0).
  The shared halves of the unary and binary constraints are `UnaryConstraint` and `BinaryConstraint`
  values held by each constraint (composition for inheritance). C++ frees its object graph with its
  object tracker (G "C++": "for arbitrary object graphs, as in DeltaBlue, `memory/object_tracker.h`
  can be used"); sysl tracks every variable so the benchmark breaks the variable–constraint cycles at
  its end, the same role.
- **Havlak**: the `ControlFlowGraph`, `LoopStructureGraph` and `HavlakLoopFinder` own their blocks,
  loops and union-find nodes, as G "C++" says for Havlak, and their `Drop`s break the cycles (block
  edges, loop parent and child links, union-find parents). A union-find node's parent, block and loop
  are `Option`s. The finder's `nodes` array is made by repeating one new node and then filling every
  slot with its own, as C++ fills a `new UnionFindNode*[size]`.
- **Json**: the current character is a one-byte slice of the input (CL excludes a character type;
  upstream's ports all use a one-character string: C++ `substr(i, 1)`, Java `substring`). A sysl
  slice allocates nothing; C++'s one-character `std::string` lives in its small-string buffer and
  allocates nothing either; Java's `substring` allocates. A parse error panics with the message, line
  and column C++ would throw. A captured string (a number or a string's text) is a `.copy()` of its
  part of the input, as C++'s `substr` and Java's `substring` copy it; a slice would share the input's
  storage for free. The JSON literals are allocated objects, as G "C++" says for Json. The
  document is a `const` generated from the Java source and checked against it; the parser reads it in
  place, as Java's does, where C++ copies it into the parser on every iteration (METHODOLOGY.md,
  section 9, gives the cost).
- **Richards**: `RBObject` is gone: it is a base class whose only member is `append`, which uses no
  state, so its constants are module constants and `append` a module function. A task's private data
  is the enum `TaskData`, which each task function takes apart with `match` where C++ uses
  `dynamic_cast` and Java a cast. The `dynamic_cast` costs C++ about 30% of Richards' time
  (METHODOLOGY.md, section 9); the `match` is sysl's checked downcast and stays. The task functions capture the scheduler, as C++'s `[this]`;
  `Scheduler.release_all` lets go of the tasks at the end of a run, breaking that cycle, as C++'s
  `ObjectTracker::releaseAll()` frees them (G "C++", Richards).

### Fixed in the port for the definitive run

These were differences of structure or of work, now made as upstream's:

- **CD**: `put` had `tree_insert` and its `InsertResult` written into it; they are separate again.
  `recurse`, `reduce_collision_set`, `voxel_hash` and `draw_motion_on_voxel_map` were module
  functions; they are `CollisionDetector`'s methods, as C++'s (its `static` `is_in_voxel` and
  `put_into_map` stay module functions).
- **Sieve**: the flags were made `true` in one step and passed by reference (Java's way); they are now
  zeroed, filled and passed by value, as C++ does, so sysl does C++'s copy too.
- **List**, **Mandelbrot**, **NBody**, **Havlak**, **Json**: helpers that are instance methods in C++
  (`makeList`, `isShorterThan`, `tail`; the private `verify_result` overloads and `mandelbrot`;
  `stringHash`, `hashSlotFor`) were module functions; they are methods. Json's slot mask is computed
  from the table's size, as C++'s, instead of the constant 31.
- **NBody** looped to `self.bodies.len`, the array's compile-time length of 5, so the optimiser could
  unroll every loop; C++ loops to the field `_bodiesSize`. It now loops to a `bodies_size` field as
  C++ does. Measured by the audit, the constant bound had made sysl NBody 31% faster (6.43 to 4.46
  ms per iteration), and C++ with its bound made `constexpr` runs in 4.48 ms.
- **Json** answered each captured string as a slice of the input, sharing its storage, where C++ and
  Java copy it. It now copies it; the slice had made sysl Json 22% faster (16.86 to 13.10 ms).
- **The manifest** said sysl 0.11.10; the sources need 0.12.0 (`@no_fuse`).

## The Zig port

Upstream has no Zig port. The only public one found (`larrydewey/Resid`, `bench/v2/t1-awfy/zig`, MIT)
does not build on Zig 0.17.1 and uses arenas where the C++ port frees objects one by one, so
`benchmarks/Zig/` is original, written for this benchmark from the C++ port at the pinned commit, file
for file: `harness.zig`, `run.zig`, `benchmark.zig`, `mem.zig` (the heap and `object_tracker`),
`som/` (Vector, Dictionary, Set, Random) and one file per benchmark. It is built as one module by
Zig 0.17.1: `zig build-exe -O fast -mcpu=native -lc harness.zig` (`-O fast` is ReleaseFast).

What keeps C++'s structure:

- **Allocation**: every `new`/`delete` is a `mem.create`/`mem.destroy` through libc's malloc and
  free, the allocator C++'s `new` uses; objects are freed where C++ frees them, and the graphs C++
  hands to `ObjectTracker` (DeltaBlue, Richards) go through the same tracker. A Debug build
  allocates through `DebugAllocator` and the harness fails a run that leaks (`scripts/leaks.zsh`).
- **Dispatch**: the `Benchmark` interface and DeltaBlue's constraint hierarchy are vtables (a table of
  function pointers plus `@fieldParentPtr`), C++'s virtual calls. Richards' task functions are a
  context (the scheduler) plus a function pointer, the indirect call of C++'s `std::function`; its
  data records are `*anyopaque`. Json's values are a kind tag plus `@fieldParentPtr`; their virtual
  methods are only type tests, and each node is still its own allocation.
- Collection `forEach`/`hasSome` take a context plus a comptime function, as `std.sort` does; C++
  passes a lambda to a template.
- An uncaught C++ exception is a `@panic`.

Every structural difference from the C++ port, and why:

- **Bounds checks**: ReleaseFast has no safety checks, so the indexing C++ does with `.at()` (CD,
  DeltaBlue, Havlak, Json, NBody, Richards, Towers; upstream's C++ guideline) is unchecked here. The suite's own `Vector` is unchecked in
  both.
- **List**: the element value is an `i32`; C++ holds it in a `std::any` (an `int` in its small buffer,
  no allocation), upstream's Java in an `Object`. Zig has no `std::any`.
- **The `Benchmark` interface**: `benchmark()` answers the benchmark's own result type; C++ answers a
  `std::any` that `verifyResult` casts back.
- **Json**: a string borrows from the constant input unless it holds an escape (std.json's
  `.alloc_if_needed`); C++ copies each into a `std::string`, which for most of the document's short
  strings is its small buffer, no allocation. The document has no escapes.
- **Dictionary**: `Entry::match` is a plain method; C++'s override has the same body as the base.
- **IdentitySet** is `Set`: C++'s `IdentitySet::contains` hides rather than overrides
  `Set::contains`, so `add`, its only caller, uses `equal` in both.
- **CD** calls Zig's `@cos`/`@sin` builtins where C++ calls libm's `cos`/`sin`; the collision counts
  the benchmark checks come out the same at every size run (`scripts/verify.zsh`).
- **Null checks** C++ makes on a pointer its types guarantee non-null are dropped where Zig's types
  forbid null (`*T` against `?*T`).

## The C port

Upstream has no C port. The only public one (`rochus-keller/Are-we-fast-yet`, `C/`, MIT) does not
build without `-w` (13 calls through mismatched function-pointer types, which are undefined
behaviour), is pinned to upstream 770c6649, and was derived from its author's own C++ port, not
upstream's: DeltaBlue uses tagged unions where C++ has virtuals. So `benchmarks/C/` is original,
written for this benchmark from the C++ port at the pinned commit, file for file: `src/harness.c`
(`harness.cpp` and `run.h`), `src/benchmark.h`, `src/memory/object_tracker.{h,c}`, `src/som/`
(Vector, Set, IdentityDictionary, Random, Error) and one `.c` per benchmark. `build.sh` compiles every
file in one clang invocation with the C++ column's clang and `OPT` (`-O3 -flto -mcpu=native`), plus
`-ffp-contract=off -std=c17 -Wall -Wextra -Werror`, as upstream's `build.sh` adds
`-ffp-contract=off -std=c++17` for C++.

What keeps C++'s structure:

- **Templates are typed modules**: `DEFINE_VECTOR`, `DEFINE_SET`, `DEFINE_IDENTITY_DICTIONARY` and
  CD's `DEFINE_RED_BLACK_TREE` generate a struct and its functions for one element type, as a C++
  template instantiation does: elements stored inline and by value, monomorphic code. Upstream's
  quirks are kept (`atPut` reallocates past the end, `sort`'s `swap` exits, `removeAll` reallocates).
- **Virtuals are vtables**: every class with a virtual member has a `const` table of function
  pointers, and a call through it is C++'s virtual call: `Benchmark`, DeltaBlue's constraint
  hierarchy (one table per concrete class, filled as C++ resolves the overrides), Json's `JsonValue`
  (every `is*`/`as*` test is a call through the table), the dictionary's entries and `newEntry`, and
  the virtual destructor of every `TrackedObject`.
- **Allocation**: every `new`/`delete` is a `malloc`/`free`, at the same place and of the same object;
  destructors are `_deinit`/`_delete` functions called where C++ runs them (a stack object's at the end
  of its scope). DeltaBlue and Richards register their objects with the same `ObjectTracker`.
- **Closures** are a function pointer and a context pointer, the indirect call of C++'s
  `std::function`.
- An uncaught C++ exception is `error()`: it prints the message and exits 1.

Every structural difference from the C++ port, and why:

- **`std::any`** (the `Benchmark` result, List's element value) is a `Result` union and an `int32_t`:
  C has no top type. Each benchmark reads back the member it wrote.
- **Bounds checks**: the indexing C++ does with `.at()` is plain indexing; the suite's own `Vector`
  checks as C++'s does.
- **Overloads**: C has none, so CD's static `benchmark(int)` is `CD_run` and the private
  `verify_result` overloads (CD, Havlak, Mandelbrot, NBody) are named `verify`.
- **Richards' `dynamic_cast`** is a comparison of the vtable pointer, a checked downcast that yields
  `NULL` on a mismatch, as `dynamic_cast` does.
- **Json**: the current character is an `int` (a byte, or -1 at the end) where C++ holds a
  one-character `std::string` in its small buffer; C has a character type and no string type. Owned
  strings are `{char*, length}`, each `malloc`ed, where libc++ keeps the document's short strings in
  its small buffer without allocating: more work for C, not less. A parsed name moves into its object
  where C++ copies it in and destroys its own. `toString()` answers the stored bytes where C++ copies
  them; it is reached only on an error. The parser copies the document into its own buffer on every
  iteration, as C++'s by-value constructor does.
- **CD**: `std::optional<V>` is a `{has_value, value}` struct. The tree's `remove` unlinks its node
  without freeing it, as C++'s; the benchmark never removes an aircraft, so it never runs.
- **IdentitySet** is `Set`, as in the Zig port: C++'s `IdentitySet::contains` hides `Set::contains`,
  so `add`, its only caller, uses `equal` in both.

## The Rust port

Upstream has no Rust port. The public ones found were rejected: `larrydewey/Resid`
(`bench/v2/t1-awfy/rust`, MIT) replaces Richards' task closures with an enum dispatch over index
arenas, and `icantcodefyi/sakuralang` has only Havlak, over arena indices. So `benchmarks/Rust/` is
original, written for this benchmark from the C++ port at the pinned commit, file for file:
`src/main.rs` (`harness.cpp` and `run.h`), `src/benchmark.rs`, `src/memory.rs` (`object_tracker`),
`src/som/` (Vector, Set, IdentityDictionary, Random) and one file per benchmark. It has no
dependencies. It is built by cargo with Rust 1.94.0 (`rustc 1.94.0 (4a4ef493e 2026-03-02)`, LLVM 21.1.8)
at `opt-level = 3`, `lto = "fat"`, `codegen-units = 1`, `panic = "abort"` (`Cargo.toml`) and
`RUSTFLAGS='-C target-cpu=native'`: the counterpart of C++'s `-O3 -flto -mcpu=native`. Rust never
contracts a multiply and an add, which is C++'s `-ffp-contract=off`.

It is safe Rust except three `unsafe` blocks, all in `memory.rs`, each with its proof in a `SAFETY`
comment:

- **`Tracker::track`** answers a `&T` into a `Box` the tracker owns. Why: the objects C++ links with
  raw pointers in cyclic graphs (DeltaBlue's variables and constraints, CD's red-black tree nodes with
  their parent pointers, Havlak's blocks, loops and union-find nodes) are each one allocation,
  referenced by `&` and mutated through `Cell`s, and freed together when the tracker is, which is where
  C++ frees them. `Rc`/`Weak` would add a reference count to every link and a count update to every
  traversal step, work the C++ port does not do; indices into a `Vec` would make the objects one
  allocation, not one each.
- **`ObjectTracker::track` and its `Drop`** hold Richards' objects of different types and free their
  memory without running anything; a compile-time assertion admits only types with no destructor.
  Why: Richards' task functions are `dyn Fn` closures, and Rust's drop checker refuses a `dyn` value
  inside a self-referential tracker (it assumes a trait object's destructor may read the references in
  its type, E0597), so the typed `Tracker` cannot hold them.

What keeps C++'s structure:

- **Allocation**: every `new` is one `Box` (or `Box<[T]>`) or one tracked object, at the same place and
  of the same object, and is freed where C++ deletes it (`Drop` at the end of the owner's scope, as a
  C++ destructor). The graphs C++ hands to `ObjectTracker` (DeltaBlue, Richards) are in a tracker.
- **Virtuals**: the `Benchmark` harness call, DeltaBlue's constraint hierarchy and Json's `JsonValue`
  are trait objects called through `&dyn`/`Box<dyn>`, C++'s virtual calls. Richards' task functions
  are closures capturing the scheduler, called through `&dyn Fn`, the indirect call of
  `std::function`.
- **som/**: the suite's own `Vector` (first index, capacity 10 doubling, its quicksort), `Set`,
  `IdentityDictionary` (C++'s bucket splitting, quirks included) and `Random`. A `Vec` is only the
  storage C++ allocates with `new E[n]`; its algorithms are never used.
- An uncaught C++ exception is a panic, which aborts.

Every structural difference from the C++ port, and why:

- **Tracker beside its owner** (CD's trees, Havlak's graph, loop structure graphs and loop finder):
  a Rust struct cannot hold references into its own fields, so the caller declares the tracker on the
  line before the object that owns the nodes in C++, and both are freed at the end of the same scope.
- **The `Benchmark` interface**: `benchmark()` answers an associated `Result` type; C++ answers a
  `std::any` that `verifyResult` casts back.
- **List**: the element value is an `i32`; C++ holds it in a `std::any`, an `int` in its small buffer.
- **Bounds checks**: Rust's indexing is checked, so the suite's own `Vector` checks where C++'s does
  not; the indexing C++ does with `.at()` is checked in both.
- **DeltaBlue**: C++ keeps the strength tables in static members, set up at the start of `chainTest`
  and released at the end of `projectionTest`; Rust has no mutable global without `unsafe` or a lock,
  so `inner_benchmark_loop` builds the same tables at the same point and passes them to both tests.
- **Richards' `dynamic_cast`** of a task's data record is a `match` on the record's enum.
- **Json**: a parse error is a panic with C++'s `ParseException` message. The parser borrows the copy
  of the document the caller makes, where C++'s by-value constructor copies it, so the current
  character can be a one-character slice. Strings are `String`s, which allocate where libc++ keeps the
  document's short strings in its small buffer: more work for Rust, not less.
- **CD**: a node's value is a `RefCell`, so `get` answers it for in-place appends as C++'s `V*` does,
  and a voxel's motion vector is an `Option<Box<Vector>>` so the voxel map can hand it on, as C++
  copies the pointer. The tree's `remove` unlinks its node; the node is freed with the tree (C++ never
  frees it). The benchmark never removes an aircraft, so it never runs.
- **IdentitySet** is `Set`, as in the Zig and C ports.

