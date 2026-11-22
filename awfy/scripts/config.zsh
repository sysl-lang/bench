# The settings every script of the AWFY track reads. METHODOLOGY.md justifies each one.
# Sourced, never run. Paths are relative to AWFY_ROOT, the awfy/ directory.

AWFY_ROOT=${AWFY_ROOT:-${${(%):-%x}:A:h:h}}
BUILD=${BUILD:-$AWFY_ROOT/build}

# Upstream: the repository and the commit every vendored file is checked against.
UPSTREAM_URL=https://github.com/smarr/are-we-fast-yet.git
UPSTREAM_COMMIT=f35aed0a61171594804a44efe9d75f1f35360700
UPSTREAM_DIR=$BUILD/upstream

# The files kept here that are upstream's, byte for byte: "<path here>=<path upstream>".
# A directory is compared recursively, dotfiles included.
UPSTREAM_FILES=(
  benchmarks/C++=benchmarks/C++
  benchmarks/script.inc=benchmarks/script.inc
  rebench.conf=rebench.conf
  LICENSE-awfy.md=LICENSE.md
  CITATION.bib=CITATION.bib
)

# The languages run, in the order a timing invocation starts with (it alternates; run.zsh).
# reproduce.zsh --langs overrides it and hands it to each script as a space-separated LANGS in the
# environment (an array cannot be exported); the second line splits that string.
(( ${+LANGS} )) || LANGS=(sysl cpp)
LANGS=(${=LANGS})

# Each benchmark's inner iterations: upstream rebench.conf, benchmark_suites.all.benchmarks.
BENCHMARKS=(DeltaBlue Richards Json CD Havlak Bounce List Mandelbrot NBody Permute Queens Sieve Storage Towers)
typeset -A INNER
INNER=(DeltaBlue 12000 Richards 100 Json 100 CD 250 Havlak 1500
       Bounce 1500 List 1500 Mandelbrot 500 NBody 250000 Permute 1000 Queens 1000 Sieve 3000
       Storage 1000 Towers 600)

# Iterations per invocation: upstream rebench.conf gives the C++ executor `iterations: *SLOW_VM`, 10.
# sysl is compiled ahead of time as C++ is, so it gets the same. Invocations: upstream runs one
# (ReBench's default); here 30, for the between-process variance (METHODOLOGY.md, section 4).
ITERATIONS=${ITERATIONS:-10}
INVOCATIONS=${INVOCATIONS:-30}

# The one clang both languages are built with. sysl hands its LLVM IR to this clang (`--cc`), and
# upstream's build.sh is given its C++ driver (CXX), so both columns share one optimizer and back end.
CLANG=${CLANG:-$(command -v clang)}
CLANGXX=${CLANGXX:-${CLANG:h}/clang++}

# The sysl compiler. SYSL_MIN is the first release the sources build with (`@no_fuse`).
SYSL=${SYSL:-$(command -v sysl)}
SYSL_MIN=0.12.0

# The versions the published run was made with (README.md). setup.zsh warns when they differ.
RECORDED_SYSL=0.12.0
RECORDED_CLANG='Apple clang version 21.0.0 (clang-2100.4.1.1)'

# C++: upstream build.sh's own OPT knob. Upstream's default is '-O3 -flto -march=native'; on arm64
# Apple clang reads -march=native as apple-m1, -mcpu=native as this machine's processor, which is what
# sysl's --cpu native asks for (METHODOLOGY.md, "Flags"). build.sh adds -ffp-contract=off -std=c++17.
CPP_OPT=${CPP_OPT:-'-O3 -flto -mcpu=native'}

# sysl: the same settings in sysl's words. -ffp-contract=off is `@no_fuse` at the top of every file.
SYSL_FLAGS=(--release -O3 --cpu native --lto full)

# Zig: one module (harness.zig imports every file), so the whole program is optimised together, as
# -flto gives C++ and sysl. `-O fast` is Zig 0.17's name for ReleaseFast. libc is linked for malloc,
# the allocator C++'s new/delete use.
ZIG=${ZIG:-$(command -v zig)}
ZIG_FLAGS=(-O fast -mcpu=native -lc)

# Rust: cargo's release profile in benchmarks/Rust/Cargo.toml (opt-level 3, fat LTO, one codegen
# unit, panic=abort), and this machine's processor, as C++'s -mcpu=native. RUSTC is the rustc beside
# CARGO, so a rustup proxy that cannot resolve a toolchain is not in the way.
CARGO=${CARGO:-$(command -v cargo)}
RUSTFLAGS_AWFY='-C target-cpu=native'

harness_of() {  # <lang>
  case $1 in
    sysl) print -r -- $BUILD/harness-sysl ;;
    cpp)  print -r -- $UPSTREAM_DIR/benchmarks/C++/harness ;;
    zig)  print -r -- $BUILD/harness-zig ;;
    rust) print -r -- $BUILD/harness-rust ;;
  esac
}
