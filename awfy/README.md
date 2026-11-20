# Are We Fast Yet, in sysl

A port of the **Are We Fast Yet** benchmark suite to sysl, timed against the suite's own C++ port
(the comparison baseline). Upstream's Java port is not run: the bench times no garbage-collected
language (the repository README, rule 9).

Are We Fast Yet (AWFY) is fourteen benchmarks designed for comparing language implementations
fairly. Unlike the Benchmarks Game, a port may not pick its own algorithm or data structure: every
language uses the same *core language* — objects with fields, polymorphic methods, closures,
fixed-size arrays, strings — the same collection classes, written as part of the suite (`som`), the
same harness, and a built-in check of every result. What is compared is how well each compiler does
with the same program.

> Stefan Marr, Benoit Daloze, Hanspeter Mössenböck. *Cross-Language Compiler Benchmarking: Are We
> Fast Yet?* Proceedings of the 12th Symposium on Dynamic Languages (DLS '16), ACM, 2016, pp.
> 120–131. [doi:10.1145/2989225.2989232](https://doi.org/10.1145/2989225.2989232).
> Source: <https://github.com/smarr/are-we-fast-yet> (MIT, [LICENSE-awfy.md](LICENSE-awfy.md),
> [CITATION.bib](CITATION.bib)).

## The benchmarks

| | benchmark | what it exercises | inner iterations |
|---|---|---|---:|
| micro | Bounce | objects in a fixed array, branching | 1500 |
| | List | recursion over linked lists | 1500 |
| | Mandelbrot | floating point in loops | 500 |
| | NBody | floating point, field access | 250000 |
| | Permute | recursion, array swaps | 1000 |
| | Queens | recursion, boolean arrays | 1000 |
| | Sieve | array writes in loops | 3000 |
| | Storage | allocating a tree of arrays | 1000 |
| | Towers | linked-list stacks, recursion | 600 |
| macro | CD | collision detection: a red-black tree, vectors of values, closures | 250 |
| | DeltaBlue | a constraint solver: polymorphism over constraints, an object graph | 12000 |
| | Havlak | loop recognition: graphs, sets, a dictionary, union-find | 1500 |
| | Json | parsing a 30 KB document into a tree | 100 |
| | Richards | an OS task scheduler: closures, linked queues | 100 |

The inner iterations are upstream's (`rebench.conf`); a benchmark's own check is written against
exactly those sizes.

## The rules this port follows

Upstream's [guidelines](https://github.com/smarr/are-we-fast-yet/blob/main/docs/guidelines.md) and
[core language](https://github.com/smarr/are-we-fast-yet/blob/main/docs/core-language.md), applied to
sysl:

1. **As identical as possible.** Each class, method and loop of upstream's Java and C++ ports has its
   counterpart, in the same order and under the same name (in sysl's `snake_case`). Iteration over a
   collection is its `for_each` with a closure, as upstream asks.
2. **The suite's own collections.** `som/` is upstream's `Vector`, `Set`, `IdentitySet`,
   `IdentityDictionary` and `Random`, written in sysl over fixed-size storage that the collection
   grows itself — never `Buf` or `Map`.
3. **Idiomatic within that.** The sysl is written as the org writes sysl (`~/dev/sysl-lang/CLAUDE.md`,
   "Writing sysl — style"): inferred types, `&T` for shared objects, `Option` where C++ has a null
   pointer, a trait where C++ has a virtual method, `match` and `is` over options. Where idiom and
   the guidelines disagree, the guidelines win (SOURCES.md lists every case).
4. **No `break` or `continue` in a benchmark's loops**, and a `return` from inside a loop only in an
   `if`, as the core language requires; loops over an optional link are `while x is Some(n)`.
5. **No leaks.** AWFY's C++ rules say a benchmark runs without leaking. sysl counts references, so a
   cycle needs breaking: each owner that C++ frees with a destructor breaks its graph's cycles in a
   `Drop` (Havlak's graphs and loop finder, CD's red-black tree), and Richards releases its tasks at
   the end of a run as C++'s object tracker does. A counted-heap build (`SYSL_COUNT_ALLOCS=1`) ends
   every benchmark with a net count of zero.
6. **Built-in verification.** The harness stops with `Benchmark failed with incorrect result` and exit
   status 1 when a benchmark's check fails. `run.zsh verify` runs every benchmark once at its standard
   size in every language.

## Flags and versions

| language | compiler | flags |
|---|---|---|
| sysl | the `sysl` on PATH (Homebrew), **0.12.0 or later**, and with `SYSL_DEV=<binary> SYSL_DEV_LIB=<library dir>` a second compiler as `sysl-dev`; each run's results name both versions | `sysl build --release -O3 --cpu native`; every file of the module is `@no_fuse` |
| C++ | Apple clang 21.0.0 (clang-2100.4.1.1) | `-O3 -flto -mcpu=native -ffp-contract=off -std=c++17` (upstream `build.sh`, with `-mcpu=native` for its `-march=native`) |

**The two languages are built with the same floating-point and processor settings.** Upstream builds
C++ with `-ffp-contract=off`, so no multiply is fused with the add it feeds; every sysl file starts
with `@no_fuse`, which is the same rule for the whole module. Before it, sysl fused where C++ did not,
which gave sysl one instruction fewer per multiply-add on CD and kept Mandelbrot and NBody from
passing their exact checks (AUDIT.md A5). On arm64 Apple clang reads `-march=native` as the apple-m1
processor and its features, while `-mcpu=native` and sysl's `--cpu native` name this machine's own
(AUDIT.md A1).

**Rust:** upstream has no Rust port (its README asks for one, "guided by our C++ port"), so none is
timed here.

## What is measured

`scripts/run.zsh time` runs each benchmark in each language as
`harness <Benchmark> <outer> <inner>`, three invocations by default. Each outer iteration runs the
benchmark's inner loop and is timed **by the harness itself** with a monotonic clock, as upstream's
harness does and as upstream reports (ReBench parses those lines). The outer iterations are upstream's
per executor: 10 for C++, and so for sysl, also compiled ahead of time.

The harness's own times are used rather than hyperfine over the process because what AWFY compares is
the steady-state cost of the benchmark's code, as upstream reports it. Each
invocation also runs under `/usr/bin/time -l` for its peak resident set size.

Reported, in `results/<date>.json` (every iteration) and `results/<date>.md`:

- mean time per iteration ± standard deviation, per benchmark and language;
- each language's ratio to C++ per benchmark, and the geometric mean of the ratios;
- peak RSS per benchmark and language;
- the size of the harness binary;
- the build time of each harness (for sysl, `sysl build` of the whole suite from cold).

## Running it

```
zsh scripts/run.zsh build
zsh scripts/run.zsh verify
zsh scripts/run.zsh time
```

Every heavy run on this machine goes through marshal, and a timing run owns it:

```
caffeinate -dimsu marshal run --dir ~/dev/sysl-lang/bench/awfy --deadline 30m --label "awfy build+verify" -- zsh scripts/run.zsh build
caffeinate -dimsu marshal run --exclusive --quiet-load auto --dir ~/dev/sysl-lang/bench/awfy --deadline 2h --label "awfy time" -- zsh scripts/run.zsh time
```

## Gaps

None from sysl 0.12.0: every benchmark runs in both languages, so no geometric mean is taken over a
subset. `run.zsh` keeps its `SKIP` and `OMIT` tables, empty, for a benchmark a sysl compiler cannot
run, and says why when one is listed. The sources need 0.12.0: DeltaBlue compares its
`&AbstractConstraint` trait objects with `===`, which 0.11 refuses, and every file is `@no_fuse`,
which 0.11 does not have. All fourteen benchmarks were verified on a 0.12 candidate (AUDIT.md A5).
