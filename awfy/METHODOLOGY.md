# Methodology

Every choice this track makes, and why. `reproduce.zsh` carries out exactly what this file says; the
settings live in one place, `scripts/config.zsh`, and every number in a report is computed by
`scripts/report.py` from the raw JSON of a run.

The suite is **Are We Fast Yet** (AWFY): Stefan Marr, Benoit Daloze, Hanspeter Mössenböck,
*Cross-Language Compiler Benchmarking: Are We Fast Yet?*, DLS 2016,
[doi:10.1145/2989225.2989232](https://doi.org/10.1145/2989225.2989232). Its stated purpose is to
compare how well compilers do with *the same program*: every port uses the same "core language"
(objects, polymorphic methods, closures, fixed-size arrays, strings), the same collection library
written in that core, the same harness and the same result checks (upstream
[docs/core-language.md](https://github.com/smarr/are-we-fast-yet/blob/f35aed0a61171594804a44efe9d75f1f35360700/docs/core-language.md)).

## 1. Upstream, and what is kept from it

**Commit `f35aed0a61171594804a44efe9d75f1f35360700`** of <https://github.com/smarr/are-we-fast-yet>
(2026-11-15, "Fix typos and make JsonObject.table final in Java (#107)"), which was upstream's HEAD
on 2026-11-20 when this track was prepared. Pinning a commit makes the comparison repeatable; when
upstream moves, the pin is moved deliberately and the check below re-run.

Kept here, **byte for byte**, and checked against a fresh checkout of that commit by
`scripts/check-upstream.zsh` on every reproduction (it fails the run on any difference):

| here | upstream |
|---|---|
| `benchmarks/C++/` (sources, `build.sh`, lint and format configs) | `benchmarks/C++/` |
| `benchmarks/script.inc` (sourced by `build.sh`) | `benchmarks/script.inc` |
| `rebench.conf` (the iteration counts, cited below) | `rebench.conf` |
| `LICENSE-awfy.md`, `CITATION.bib` | `LICENSE.md`, `CITATION.bib` |

The same script checks that the Json benchmark's document in the sysl port
(`benchmarks/sysl/json_data.sysl`) is the Java port's string literal (`Json.java`, line 39),
character for character. No upstream file is modified, patched at build time or replaced: the C++
binary is built in the upstream checkout itself, by upstream's `build.sh`.

## 2. Languages

Upstream has ten ports (its README, "Current Status"). Each, and whether it runs here:

| port | runs | why |
|---|---|---|
| **sysl** (`benchmarks/sysl/`, written here) | **yes** | the subject. SOURCES.md documents it against upstream's porting guidelines. |
| **C++** | **yes**, the baseline of every ratio | the suite's compiled, non-garbage-collected reference, and the closest kind of language to sysl: ahead-of-time, LLVM, no collector. It is upstream's own port, so no one here chose how well it is written. |
| Crystal | no, **pending the user's decision** (section 2.1) | ahead-of-time compiled through LLVM, but garbage-collected (Boehm). |
| Java | no, **pending the user's decision** (section 2.1) | garbage-collected and JIT-compiled; it is the suite's historical normalisation baseline. |
| JavaScript, Lua, Python, Ruby | no | dynamically typed, interpreted or JIT-compiled, garbage-collected: upstream's own results put them at 1.5x to 100x Java. Their interest is VM engineering; this comparison is between ahead-of-time compilers of statically typed code. |
| Smalltalk (Squeak/Pharo), SOM, SOMns | no | research VMs of dynamic languages, for the same reason, and each needs a VM image or a VM build outside the suite. |

**Rust, Go, Zig and other compiled languages: upstream has no port.** Its README asks for a Rust one
("should be guided by our C++ port"). None is written here: a port by the sysl project of a rival
language would be the rival at *our* best, not its own, and could not be checked against an upstream.
If upstream gains one, it is added unmodified.

### 2.1 Garbage-collected ports: the recommendation awaiting a decision

The repository's other track times no garbage-collected language except Go. AWFY has no Go port, so
the question here is Java and Crystal. **Recommendation: add both, as reference columns that are not
in the headline**, which stays sysl / C++:

- **Java (HotSpot, `Java-jit` in rebench.conf)** is the baseline AWFY's own published results are
  normalised to (upstream `docs/performance.md`, "All results are normalized to Java"). A reader who
  knows the paper places a language by its factor over Java; without the column they cannot. It must
  be run as upstream runs it, which differs from C++: `iterations: *FAST_VM` (100), and a JIT's
  numbers are only meaningful after warm-up, so the report would show its steady state (upstream's
  R reports drop the warm-up iterations; the cut-off would be written down here) and also its first
  iterations. Its times include collection.
- **Crystal** is upstream's only other ahead-of-time, LLVM-compiled port (`crystal build --release
  --no-debug`, upstream's `build.sh`). It is the nearest thing to a second compiled rival upstream
  offers. rebench.conf gives it no iteration count (ReBench's default, 1); it would get C++'s 10.

Neither is added until the user decides.

## 3. Flags

Both ports are compiled by **the same clang** (Apple clang 21.0.0 here): sysl emits LLVM IR and
hands it to the clang named by `--cc`; upstream's `build.sh` is given that clang's `clang++` as
`CXX`. So both columns share one optimiser and one back end, and what differs is the front end and
the language, which is what AWFY means to compare.

| | C++ | sysl |
|---|---|---|
| build | upstream `build.sh`, run as `CXX=clang++ OPT='-O3 -flto -mcpu=native' bash ./build.sh` | `sysl build --release -O3 --cpu native --lto full --cc <clang>` |
| optimisation | `-O3` (build.sh's default) | `-O3` |
| whole program | `-flto` (build.sh's default; full LTO) | `--lto full` |
| processor | `-mcpu=native` (see below) | `--cpu native` |
| floating point | `-ffp-contract=off` (build.sh's `COMP_OPT`, always on) | `@no_fuse` at the top of every file: the same rule, module-wide |
| language | `-std=c++17`, `-Wall -Wextra -Wno-unused-private-field` (build.sh) | sysl 0.12.0 |
| checks | `.at()` on `std::array` is bounds-checked (upstream's C++ guideline); the suite's `Vector` indexes raw `new E[]` storage unchecked | every subscript is bounds-checked; integer overflow wraps (`--release`) |

**Why `-mcpu=native` and not build.sh's default `-march=native`.** `OPT` is build.sh's own knob,
and rebench.conf sets it (`OPT='-O3 -flto -march=native'`), so setting it is upstream's practice.
On x86, where upstream runs, `-march=native` means this machine's processor. On arm64 Apple clang
reads `-march=native` as the Apple M1 and its features (`clang -### -march=native`: `-target-cpu
apple-m1`), while `-mcpu=native` and sysl's `--cpu native` both name this machine's own processor.
`-mcpu=native` is therefore the flag that does on arm64 what upstream's does on x86, and the one
that builds both columns for the same processor. On the Apple M5 Pro used here, Apple clang 21 names
it `apple-m4` (its newest) for both: `clang -### -mcpu=native` for C++, and the processor in sysl's
cached standard-library key for sysl.

**Why `--lto full` for sysl.** C++ is linked with `-flto`, which lets the optimiser see every object
at once, including inlining across files. sysl's standard library is precompiled; without `--lto` a
call into it (the clock, the allocator, string helpers) could not be inlined while the C++ side's
could. `--lto full` is the like-for-like setting.

**`@no_fuse`** (sysl 0.12.0) is why the sources need 0.12.0. Before it, sysl fused `a * b + c` into
one instruction where C++ (`-ffp-contract=off`) does not: sysl did less floating-point work, and
Mandelbrot and NBody failed their exact checks.

PGO, sanitiser and pedantic builds (other modes of build.sh) are not used: rebench.conf uses the
plain build.

## 4. Iterations, invocations and warm-up

- **Inner iterations** (the problem size) are upstream's, from rebench.conf's `benchmarks:` list:
  DeltaBlue 12000, Richards 100, Json 100, CD 250, Havlak 1500, Bounce 1500, List 1500, Mandelbrot
  500, NBody 250000, Permute 1000, Queens 1000, Sieve 3000, Storage 1000, Towers 600. Each
  benchmark's built-in check is written for exactly these sizes.
- **Iterations per invocation: 10**, upstream's `iterations: *SLOW_VM` for the C++ executor. sysl is
  compiled ahead of time like C++, so it is run the same way. The harness times each iteration
  itself, with a monotonic clock, in microseconds, and prints the line ReBench's `RebenchLog` adapter
  reads; those lines are the measurements, as upstream reports them.
- **Invocations: 30.** rebench.conf sets none (ReBench's default is one process). One process
  cannot show the variation between processes (address-space layout, the allocator's state, which
  core the scheduler picks), which Kalibera and Jones show is often the larger part of the variance
  (*Rigorous Benchmarking in Reasonable Time*, ISMM 2013). Thirty independent processes per
  benchmark and language give the interval in section 5 enough to resample. The suite is quick here
  (an iteration takes 5 to 125 ms; one invocation of all fourteen benchmarks in both languages about
  8 s), so thirty cost about four minutes.
- **Warm-up: none discarded.** Upstream discards no iterations for C++ (rebench.conf sets no warm-up,
  and a compiled program has no JIT to warm). The first iteration of a process can still pay for
  page faults and cold caches, so the report also gives the geometric mean **without each
  invocation's first iteration**, as a sensitivity check. If the two disagree materially, that is
  reported, not hidden.
- **Order.** Invocation by invocation, each benchmark in turn, the two languages alternating which
  runs first (`scripts/run.zsh`). A slow drift in the machine's state (temperature, background work)
  lands on both languages alike instead of on whichever runs last. The order is recorded in the JSON.

## 5. The statistic

- **Per benchmark and language:** the arithmetic mean of all 300 iteration times (30 invocations × 10
  iterations), and their sample standard deviation. The mean is what upstream's ReBench and its R
  reports use for a configuration's time; the standard deviation is published beside it so that
  noise is visible, and the JSON keeps every iteration for any other statistic a reader prefers.
- **The ratio** for a benchmark is sysl's mean over C++'s. Below 1, sysl is faster.
- **The headline** is the **geometric mean of the fourteen ratios**: the mean that does not depend on
  which language is the baseline (Fleming and Wallace, *How not to lie with statistics*, CACM 1986),
  and the summary upstream's own results use ("Runtime Factor over Java", geomean). Every benchmark
  weighs the same.
- **Intervals: 95%, percentile bootstrap, resampling whole invocations.** In each of 10,000
  replicates, each benchmark's thirty sysl invocations and thirty C++ invocations are resampled with
  replacement, separately; an invocation keeps its ten iterations together, because iterations of one
  process are not independent of each other, while separate processes are. Each replicate gives a
  ratio per benchmark and a geometric mean; the 2.5th and 97.5th percentiles are the interval. The
  seed is fixed, so the same JSON always gives the same report.
- **Peak resident set size** per benchmark and language (`/usr/bin/time -l`), the binaries' sizes
  and the build times are recorded and reported, and are not part of any ratio.

## 6. One thread

AWFY is a single-threaded suite: neither port's source starts a thread, and the harness runs one
benchmark at a time in one process. Nothing is parallelised for either language, and only one
benchmark process runs at a time.

## 7. The machine

- **One machine**, named in every report from the machine itself (model, processor, P- and E-core
  counts, memory, OS and build) and recorded in the JSON.
- **On AC power, kept awake.** `reproduce.zsh` re-runs itself under `caffeinate -dimsu` on macOS:
  a system sleep stops every process mid-iteration, which once on this machine looked exactly like a
  slow benchmark. It warns if the machine is on battery or has a sleep timer set.
- **Quiet.** Nothing else heavy runs during a timing run: no builds, no other benchmarks, no indexing
  burst. Here that is enforced by running the timed run as the only job on the machine's job manager
  (`marshal run --exclusive --quiet-load auto`, which waits for the load to settle); elsewhere it is
  the reproducer's responsibility. The load average at the start and end is recorded in the JSON.
- **No core pinning.** macOS offers no way to pin a process to a core or to keep it off the
  efficiency cores. Both languages are equally exposed; a process landing on an E-core shows as an
  outlier invocation, which the standard deviation and the interval carry.

## 8. Excluded

- The garbage-collected and dynamic-language ports (section 2), pending the decision in 2.1.
- Build modes other than upstream's plain one (PGO, sanitisers).
- Start-up time: the harness times only its iterations, as upstream's does; process start-up, the
  benchmark's construction and the final report are outside every measurement.
- A second sysl compiler side by side (the repository's earlier `SYSL_DEV`): a definitive run times
  one released compiler, named in the report. `SYSL=<binary>` points the scripts at another one.

## 9. Threats to validity

- **One machine, one OS, one architecture: tested on macOS arm64 only.** Ratios on x86 or Linux may
  differ, and the scripts have not been run there. Three things are known to break or skew a run
  off macOS arm64: `run.zsh` times each process with `/usr/bin/time -l`, which GNU time rejects, so a
  Linux run stops at its first process; `reproduce.zsh` reads binary sizes with BSD `stat -f %z`;
  and on x86 clang reads `-mcpu=native` as the generic `x86-64` while sysl's `--cpu native` still
  targets the host, so C++ would lose its native instruction set (upstream's `-march=native` is the
  x86 flag; section 3). `setup.zsh` warns on any other platform.
- **Apple clang 21, not upstream's clang 22.** Both columns use the same clang, so the comparison is
  fair to both; the absolute C++ times are not those of upstream's CI. Whether Homebrew's LLVM 22
  would make the C++ column faster was not measured; `CLANG=<llvm 22 clang>` runs both columns with
  it.
- **Versions are recorded, not pinned.** The published run used the versions in README.md
  (`config.zsh`, `RECORDED_SYSL` and `RECORDED_CLANG`); a reproduction with a different sysl or clang
  measures a different optimiser, and `setup.zsh` prints a warning naming the difference.
- **The harness dispatch.** C++ calls `benchmark()` and `verify_result(std::any)` through a virtual
  table on every inner iteration; sysl's harness selects the benchmark by name and runs it through a
  generic, so those two calls are direct (SOURCES.md). One indirect call per inner iteration against
  the iteration's work is far below the measurement noise, but it is a difference in sysl's favour.
  The audit checked that the direct calls let nothing be hoisted out of the inner loop: doubling the
  inner iterations doubles the time in both languages for all seven benchmarks that use the default
  loop (sysl 1.978 to 2.039, C++ 1.983 to 2.013).
- **Work sysl does that C++ does not.** sysl counts references on every shared object; C++ frees by
  hand. sysl heap-allocates some objects C++ keeps on the stack (CD's per-frame vectors and trees),
  and checks every subscript (C++ checks only `std::array::at`). These cost sysl time.
- **Work C++ does that sysl does not.** Each is upstream's C++, which stays unmodified; the numbers
  are the audit's (one `marshal --exclusive` job, 10 alternating invocations x 10 iterations of each
  variant against its base, both built with this track's flags).
  - *Closures.* Upstream's C++ takes every closure as a `std::function` (`som/vector.h` `forEach`,
    `hasSome`, `getOne`; `som/set.h`; `cd.h:458`): a type-erased call built and made per element.
    sysl's ordinary closure parameter (`f: E -> unit`) is generic, so each call site gets its own
    copy, like a C++ `template <typename F>`. Both are each language's idiomatic form of the same
    source-level closure, which is what AWFY measures ("exercises the compiler's abilities to optimize
    closures", upstream guidelines), and upstream's own compiled port does what sysl does: Crystal
    takes `&block` and calls it with `yield` (`benchmarks/Crystal/som.cr:100`), which its compiler
    inlines at each call site. Measured, C++ with its closure parameters made templates is faster by
    **25.3% on Havlak, 6.6% on DeltaBlue**, and 2.7% on CD, 3.2% on Richards, 0.9% on Json. That is a
    lower bound: DeltaBlue's virtual `inputsDo` and the Planner's `std::function` parameters were left
    as they are.
  - *Richards' `dynamic_cast`.* C++ takes a task's private data apart with four `dynamic_cast`s
    (`richards.h:274, 303, 342, 383`), a library call on every task step on macOS; sysl matches an
    enum tag (SOURCES.md). C++ with `static_cast` in their place is **29.7% faster** on Richards.
  - *Json's document.* C++ copies the 25,820-byte document into the parser's `_input` on every inner
    iteration (`json.h:981` passes the `const string` to the constructor's by-value parameter,
    `json.h:963`). Java does not, and sysl, like
    Java, parses the literal in place. Copying it in sysl as well costs sysl a further 4.0% on Json.
  - *`std::any`.* C++'s `benchmark()` answers a `std::any` and List stores one per element; sysl
    answers a typed `Result` and stores an `int` (SOURCES.md). Unmeasured separately; the dispatch
    check above bounds the per-iteration part to a few nanoseconds against 4 µs or more of work.

  **Sensitivity of the headline.** Every item in this list favours sysl. If C++ took its closures as
  templates, the geometric mean of the sysl/C++ ratios would rise by about **3.1%** (Havlak's ratio
  alone by 34%); with `static_cast` in Richards, by a further **2.5%** (Richards' ratio by 42%); the
  Json document copy is 0.3%. Together that is about **6%** against sysl, more since the closure
  figure is a lower bound. The headline is upstream's C++ as published, and these are the amounts by
  which a C++ programmer free to depart from it could move it.
- **A result check cannot catch every change.** Each benchmark checks its own result, which catches
  a wrong program, but not every edit to one: the audit changed Bounce's `x_limit` to 499 and the
  count stayed 1331 in both languages. The checks are upstream's, unchanged.
- **Mean, not median.** An outlier iteration moves the mean; the standard deviation, the interval and
  the raw JSON show whether one did.
- **The interval assumes invocations are independent and alike.** A machine whose state changes
  during the run (thermal throttling, a background job) violates that; the alternation of languages
  spreads such a change over both columns, and the start and end load averages are recorded.
- **Timer resolution.** The harness times in whole microseconds; the shortest iterations here are
  several milliseconds, so rounding is below 0.1%.
- **The sysl port is written by the sysl project.** It follows upstream's guidelines, and every
  structural difference from upstream's C++ and Java is listed with its reason in SOURCES.md, so a
  reader can check that it does the same work. An independent audit of the port and the scripts was
  made before the first published run. It found two differences that favoured sysl by about 4.5% of
  the geometric mean, NBody's loop bound and Json's uncopied captures; both are fixed in the port
  (SOURCES.md, "Fixed in the port"). Its other findings are disclosed in this section.
