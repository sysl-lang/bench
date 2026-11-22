# Are We Fast Yet: sysl and C++

The **Are We Fast Yet** benchmark suite, run in sysl against the suite's own C++ port.

Are We Fast Yet (AWFY) is fourteen benchmarks designed for comparing language implementations
fairly. Unlike the Benchmarks Game, a port may not pick its own algorithm or data structure. Every
language uses the same *core language*: objects with fields, polymorphic methods, closures,
fixed-size arrays and strings. Every port also uses the same collection classes, written as part of
the suite (`som`), the same harness, and a built-in check of every result. What is compared is how
well each compiler does with the same program.

> Stefan Marr, Benoit Daloze, Hanspeter Mössenböck. *Cross-Language Compiler Benchmarking: Are We
> Fast Yet?* Proceedings of the 12th Symposium on Dynamic Languages (DLS '16), ACM, 2016, pp.
> 120–131. [doi:10.1145/2989225.2989232](https://doi.org/10.1145/2989225.2989232).
> Source: <https://github.com/smarr/are-we-fast-yet> (MIT, [LICENSE-awfy.md](LICENSE-awfy.md),
> [CITATION.bib](CITATION.bib)).

- **C++ is upstream's port, unmodified**, at commit `f35aed0a`, and it is built by upstream's own
  `build.sh`. Every upstream file kept here is checked byte for byte against upstream on every run.
- **The sysl port** follows upstream's porting guidelines. [SOURCES.md](SOURCES.md) lists every
  structural difference from upstream's C++ and Java ports, and why each one is there.
- **[METHODOLOGY.md](METHODOLOGY.md)** gives every choice and its justification: the languages, the
  flags, the iteration counts, the statistic, the machine, what is excluded, and the threats to
  validity.

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
| | Json | parsing a 25.8 KB document into a tree | 100 |
| | Richards | an OS task scheduler: closures, linked queues | 100 |

The inner iterations are upstream's (`rebench.conf`). Each benchmark's own check is written against
exactly those sizes.

## Languages

sysl and C++ run here. Upstream's other ports (Crystal, Java, JavaScript, Lua, Python, Ruby,
Smalltalk, SOM, SOMns) are garbage-collected, and most of them are dynamic. Upstream has no Rust,
Go or Zig port. METHODOLOGY.md, section 2, gives the reason for each port, and the open question of
adding Java and Crystal as reference columns.

## Reproducing

You need macOS on Apple silicon (arm64), sysl 0.12.0 or later, clang, python3 (standard library
only) and git. That is the only platform the track is tested on. Linux and x86 are untested and
known not to work as they stand: GNU time rejects `/usr/bin/time -l`, GNU stat rejects `stat -f`,
and on x86 clang reads `-mcpu=native` as generic `x86-64` (METHODOLOGY.md, section 9).

The published run was made with **sysl 0.12.0** and **Apple clang 21.0.0 (clang-2100.4.1.1)**, from
Xcode 27.2 and its command-line tools, on macOS 27. `reproduce.zsh` prints a warning when the sysl or
clang it finds is not these: a different optimiser is a different measurement.

```
brew install sysl-lang/tap/sysl
git clone https://github.com/sysl-lang/bench
cd bench/awfy
zsh reproduce.zsh --smoke
zsh reproduce.zsh
```

1. `brew install sysl-lang/tap/sysl` installs sysl together with the LLVM it needs. On macOS, clang
   comes with the Xcode command-line tools (`xcode-select --install`).
2. `zsh reproduce.zsh --smoke` runs everything once, with one invocation of one iteration, into
   `build/smoke/`. It takes about a minute and proves that the toolchain and the pipeline work. Its
   numbers are not a result.
3. `zsh reproduce.zsh` is the full run: 30 invocations of 10 iterations of every benchmark in both
   languages. On an Apple M5 Pro it takes about five minutes. Keep the machine on AC power and otherwise idle;
   `reproduce.zsh` keeps it awake with `caffeinate`.

`reproduce.zsh` does every step in order and stops at the first failure:

| step | script | what it does |
|---|---|---|
| setup | `scripts/setup.zsh` | prints the versions of sysl, clang and python3, says how to install any that is missing, and warns when the platform or a version is not the published run's; clones upstream at the pinned commit into `build/upstream`; then runs `scripts/check-upstream.zsh`, which fails if any upstream file kept here differs from upstream |
| build | `scripts/build.zsh` | builds C++ with upstream's `build.sh` in the upstream checkout, and builds sysl with `sysl build`, both with the same clang |
| verify | `scripts/verify.zsh` | runs every benchmark once at its timed size in both languages; the harness checks the result and exits 1 if it is wrong |
| time | `scripts/run.zsh` | runs the invocations, alternating the languages, under `/usr/bin/time -l` |
| report | `scripts/report.py` | `collect` writes `results/<stamp>.json`, which holds every iteration, the machine, the OS, the CPU, the versions, the flags and the build times; `render` writes `results/<stamp>.md` and `results/report.html` from that JSON |

The settings (upstream commit, inner iterations, flags, counts) are all in `scripts/config.zsh`.
The environment variables `INVOCATIONS`, `ITERATIONS`, `SYSL`, `CLANG` and `CPP_OPT` override them.
`scripts/leaks.zsh` checks that the sysl port frees everything it allocates. It uses sysl's counted
heap and is not part of a timing run.

**On the sysl project's own machine**, every heavy run goes through its job manager, marshal, which
others do not need. A timed run is the only job on the machine:

```
caffeinate -dimsu marshal run --kind build --dir ~/dev/sysl-lang/bench/awfy --deadline 15m --label "awfy smoke" -- zsh reproduce.zsh --smoke
caffeinate -dimsu marshal run --exclusive --quiet-load auto --dir ~/dev/sysl-lang/bench/awfy --deadline 2h --label "awfy time" -- zsh reproduce.zsh
```

## Layout

Everything the track needs is in this directory. Nothing here reads a file outside `awfy/`.

| path | |
|---|---|
| `reproduce.zsh` | the one command |
| `scripts/` | `config.zsh` (every setting), `setup.zsh`, `check-upstream.zsh`, `build.zsh`, `verify.zsh`, `run.zsh`, `report.py`, `leaks.zsh` |
| `benchmarks/C++/`, `benchmarks/script.inc`, `rebench.conf` | upstream, byte for byte |
| `benchmarks/sysl/` | the sysl port, with its manifest `sysl.hocon` |
| `results/` | published runs: raw JSON, Markdown and HTML reports |
| `build/` | upstream checkout, binaries, logs (ignored by git) |
