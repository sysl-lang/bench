# Shared definitions for the plb2 scripts. Sourced, never run.
#
# Everything the benchmark reads is under plb2/ (this file's parent's parent). Nothing outside it is
# read: the programs, the expected outputs and the scripts are all here, and the build goes to
# plb2/build/.

PLB2=${0:A:h:h}
BUILD=$PLB2/build

# The upstream commit vendored in upstream/ (UPSTREAM.md).
UPSTREAM_URL=https://github.com/attractivechaos/plb2
UPSTREAM_COMMIT=1181b3b83fea52ee85a66548845f8bf92e33fb67

# Toolchains that are not on a default PATH on the machine the results were taken on. Each is put in
# front of PATH only where it exists, so another machine's PATH is left as it is.
for dir in $HOME/.local/gnat-16.1.0/bin /Users/work/.cargo/bin $HOME/.cargo/bin /opt/homebrew/bin; do
  [[ -d $dir ]] && PATH=$dir:$PATH
done
export PATH

PROGRAMS=(nqueen matmul sudoku bedcov)

# The bench's eleven languages (METHODOLOGY.md §2). C is the baseline of every ratio.
LANGS=(c cpp rust go zig swift ada fortran odin c3 sysl)

# Where each program comes from: upstream/src/... is upstream's own file, byte-identical to the commit
# above (scripts/check-upstream.zsh); written/... is original, written for this benchmark
# (METHODOLOGY.md §3). This table is the one place provenance is decided.
typeset -A SRC
SRC=(
  c:nqueen        upstream/src/c/nqueen.c
  c:matmul        upstream/src/c/matmul.c
  c:sudoku        upstream/src/c/sudoku.c
  c:bedcov        upstream/src/c/bedcov.c
  rust:nqueen     upstream/src/rust/nqueen.rs
  rust:matmul     upstream/src/rust/matmul.rs
  rust:sudoku     upstream/src/rust/sudoku.rs
  rust:bedcov     upstream/src/rust/bedcov.rs
  go:nqueen       upstream/src/go/nqueen.go
  go:matmul       upstream/src/go/matmul.go
  go:sudoku       upstream/src/go/sudoku.go
  go:bedcov       upstream/src/go/bedcov.go
  swift:nqueen    upstream/src/swift/nqueen.swift
  swift:matmul    upstream/src/swift/matmul.swift
  swift:sudoku    upstream/src/swift/sudoku.swift
  swift:bedcov    upstream/src/swift/bedcov.swift
  fortran:nqueen  upstream/src/fortran/nqueen.F90
  fortran:matmul  upstream/src/fortran/matmul.F90
  fortran:sudoku  upstream/src/fortran/sudoku.F90
  fortran:bedcov  written/fortran/bedcov.F90
  zig:nqueen      written/zig/nqueen.zig
  zig:matmul      written/zig/matmul.zig
  zig:sudoku      written/zig/sudoku.zig
  zig:bedcov      written/zig/bedcov.zig
  cpp:nqueen      written/cpp/nqueen.cpp
  cpp:matmul      written/cpp/matmul.cpp
  cpp:sudoku      written/cpp/sudoku.cpp
  cpp:bedcov      written/cpp/bedcov.cpp
  ada:nqueen      written/ada/nqueen.adb
  ada:matmul      written/ada/matmul.adb
  ada:sudoku      written/ada/sudoku.adb
  ada:bedcov      written/ada/bedcov.adb
  odin:nqueen     written/odin/nqueen.odin
  odin:matmul     written/odin/matmul.odin
  odin:sudoku     written/odin/sudoku.odin
  odin:bedcov     written/odin/bedcov.odin
  c3:nqueen       written/c3/nqueen.c3
  c3:matmul       written/c3/matmul.c3
  c3:sudoku       written/c3/sudoku.c3
  c3:bedcov       written/c3/bedcov.c3
  sysl:nqueen     written/sysl/nqueen.sysl
  sysl:matmul     written/sysl/matmul.sysl
  sysl:sudoku     written/sysl/sudoku.sysl
  sysl:bedcov     written/sysl/bedcov.sysl
)

provenance() { [[ ${SRC[$1:$2]} == upstream/* ]] && print upstream || print written; }

exe() { print -r -- $BUILD/bin/$1/$2; }

# BENCH_LANGS / BENCH_PROGRAMS name a subset (default: all).
(( ${+BENCH_LANGS} )) && LANGS=(${=BENCH_LANGS})
(( ${+BENCH_PROGRAMS} )) && PROGRAMS=(${=BENCH_PROGRAMS})
