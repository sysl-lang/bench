# Where every file comes from

Upstream is <https://github.com/smarr/are-we-fast-yet> at commit
`f35aed0a61171594804a44efe9d75f1f35360700` (2026-11-15), MIT ([LICENSE-awfy.md](LICENSE-awfy.md)).

| path | origin |
|---|---|
| `benchmarks/C++/src/` | upstream `benchmarks/C++/src/`, unchanged |
| `benchmarks/Java/src/` | upstream `benchmarks/Java/src/`, unchanged |
| `benchmarks/sysl/` | this port, from the C++ and Java ports (below) |
| `benchmarks/sysl/json_data.sysl` | generated from line 39 of upstream `benchmarks/Java/src/Json.java` (the document, character for character) |
| `pending/` | sysl drafts that cannot pass as the guidelines require (README.md, "Gaps") |
| `LICENSE-awfy.md`, `CITATION.bib` | upstream, unchanged |
| `scripts/run.zsh`, `scripts/report.py`, `README.md`, this file | written here |

The C++ build uses upstream `build.sh`'s flags; the Java build is upstream's `ant jar` done with
`javac` directly (the target has no options).

## The sysl port, file by file

Every class, method and loop of the C++ and Java ports has its counterpart under the same name in
`snake_case`, in the same order. What follows is every place the sysl differs in structure, and why.

### Throughout

- **A class hierarchy becomes a trait or composition.** sysl has no inheritance. A virtual method is
  a trait member (`Benchmark`, `JsonValue`); state a base class holds is a field holding a struct of
  it (`TaskControlBlock.state: TaskState` in Richards).
- **A null pointer is `Option`.** `NO_WORK`, `NO_TASK` and every nullable link are `None`; a loop over
  a link is `while link is Some(n)`.
- **A shared object is `&T`, a small value is `T`.** Objects the C++ allocates with `new` are counted
  references; C++'s value classes (CD's vectors, `CallSign`, `Motion`; NBody's `Body`) are values,
  and their methods take `self` by value.
- **Freeing.** C++ deletes; sysl frees by count. Where a graph has cycles, the owner that C++ gives a
  destructor breaks them in its `Drop` (README.md, rule 5).
- **An exception is a `panic`.** C++ and Java throw an `Error` nothing catches; sysl stops the program.
- **Closures** passed to `for_each`, `has_some` and the like are arrow parameters (`f: E -> unit`),
  which sysl monomorphizes; C++ passes a `std::function`, Java a lambda the JIT inlines. A closure
  that is stored (Richards' task functions) is a `&Fn`, as C++'s `std::function` member is.

### Harness — `harness.sysl`, `run.sysl`, `benchmark.sysl`

- `Benchmark.benchmark()` answers an associated type `Result` instead of C++'s `std::any` or Java's
  `Object`; a benchmark that overrides `inner_benchmark_loop` declares `Result = bool` and panics in
  the two members it never calls, as C++'s "Should never be reached".
- `Run` picks the benchmark by a `match` on its name and runs it through a generic `do_runs`, so the
  benchmark's members are called directly. C++ calls them through a virtual table; Java finds the class
  by reflection.
- The output lines are upstream's, character for character. Time is `sysl.time.monotonic()` in
  microseconds.

### `som/`

- **`Vector`**: storage of `[]E` made by `slot_storage`, so the room past the last element holds
  nothing, as C++'s uninitialised `new E[n]` and Java's `null`s. `at`, `first`, `remove_first` and
  `get_one` answer `Option[E]`. `at_put` past the end cannot leave a gap (that slot would hold no
  element) and traps; no benchmark stores past the end. `remove` takes the comparison as a
  parameter, since the elements may be values or objects; only DeltaBlue calls it. `remove_all`
  allocates new storage of the same size, as Java does. `swap`, which C++ leaves unimplemented, is
  Java's.
- **`IdentityDictionary`** is upstream's chained hash table with its resize and bucket split. Keys are
  `&K` compared with `===`, hashed by the `CustomHash` trait. Upstream's equality `Dictionary`, of
  which `IdentityDictionary` is a subclass, is used by no benchmark and is not ported.
- **`Set`** compares with `==` (C++: `==` on `int32_t`, `equal()` on pointers); **`IdentitySet`**
  holds `&E` and compares with `===`.
- **`Random`** is upstream's.

### Micro benchmarks

- **Bounce**: the balls are a `[100]Ball` of values walked by index, since a sysl `for` over an array
  binds a copy and the balls are written.
- **List**: `Element.value` is an `int` (C++: `std::any`, Java: `Object`). `make_list`,
  `is_shorter_than` and `tail` are file-private functions rather than methods of the benchmark; they
  read no state of it.
- **Mandelbrot**, **NBody**: as upstream. Both fail their checks (README.md, "Gaps").
- **Permute**, **Queens**: the arrays are `[]int` and `[]bool` made per run, as C++ does with `new[]`.
- **Sieve**: the flags are a `[5000]bool` handed to `sieve` as a view. C++ copies the `std::array` by
  value into `sieve`; Java passes the reference, as here.
- **Storage**: an `ArrayTree` holds a `[]ArrayTree`, as C++.
- **Towers**: `piles` is a `[3]Option[&TowersDisk]`.

### Macro benchmarks

- **CD**: `RedBlackTree[K: CompareTo, V]` is generic over a key trait, as C++'s template over
  `compareTo`. Nodes hold a strong parent link; the tree's `Drop` clears the parent links, as C++'s
  destructor deletes from the root. C++'s `treeInsert` and its `InsertResult` are written into `put`,
  which is their only caller. `forEach` hands the closure an `Entry` value.
- **Havlak**: the `ControlFlowGraph`, `LoopStructureGraph` and `HavlakLoopFinder` own their blocks,
  loops and union-find nodes, as upstream's C++ rules say, and their `Drop`s break the cycles (block
  edges, loop parent and child links, union-find parents). A union-find node's parent, block and loop
  are `Option`s. The finder's `nodes` array is made by repeating one new node and then filling every
  slot with its own, as C++ fills a `new UnionFindNode*[size]`. Two names are sysl words and are
  renamed: `type` is `types`, `loop` is `found_loop`.
- **Json**: the current character is a one-byte slice of the input, which allocates nothing (Java's
  `substring` allocates; C++'s `substr` uses its small-string buffer). A parse error panics with the
  message, line and column C++ would throw. The literal's flags are `literal_null` and so on, since
  `null` is a sysl word. The document is a `const` generated from the Java source.
- **Richards**: `RBObject` is gone: its constants are module constants and `append` a free function.
  A task's private data is the enum `TaskData`, which each task function takes apart with `match`
  where C++ uses `dynamic_cast` and Java a cast. The task functions capture the scheduler, as C++'s
  `[this]`; `Scheduler.release_all` lets go of the tasks at the end of a run, breaking that cycle, as
  C++'s `ObjectTracker::releaseAll()` frees them.
- **DeltaBlue**: not ported (README.md, "Gaps"). `pending/deltablue.sysl` is the draft: constraints
  are `&AbstractConstraint` trait objects, the shared halves of the unary and binary constraints are
  `UnaryConstraint` and `BinaryConstraint` values held by each constraint, and every variable is
  tracked so the test can break the variable–constraint cycles at its end, as C++ uses its object
  tracker. It stops at `===` on a trait object.
