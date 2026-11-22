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

