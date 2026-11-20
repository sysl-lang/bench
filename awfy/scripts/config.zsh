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
LANGS=(sysl cpp)

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

# C++: upstream build.sh's own OPT knob. Upstream's default is '-O3 -flto -march=native'; on arm64
# Apple clang reads -march=native as apple-m1, -mcpu=native as this machine's processor, which is what
# sysl's --cpu native asks for (METHODOLOGY.md, "Flags"). build.sh adds -ffp-contract=off -std=c++17.
CPP_OPT=${CPP_OPT:-'-O3 -flto -mcpu=native'}

# sysl: the same settings in sysl's words. -ffp-contract=off is `@no_fuse` at the top of every file.
SYSL_FLAGS=(--release -O3 --cpu native --lto full)

harness_of() {  # <lang>
  case $1 in
    sysl) print -r -- $BUILD/harness-sysl ;;
    cpp)  print -r -- $UPSTREAM_DIR/benchmarks/C++/harness ;;
  esac
}
