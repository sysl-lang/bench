# Shared definitions for the plb2 scripts. Sourced, never run.
#
# Everything the benchmark reads is under plb2/ (this file's parent's parent). Nothing outside it is
# read: the programs, the expected outputs and the scripts are all here, and the build goes to
# plb2/build/.

PLB2=${${(%):-%x}:A:h:h}
BUILD=$PLB2/build

# The upstream commit vendored in upstream/ (UPSTREAM.md).
UPSTREAM_URL=https://github.com/attractivechaos/plb2
UPSTREAM_COMMIT=1181b3b83fea52ee85a66548845f8bf92e33fb67

# Toolchains that are not on a default PATH on the machine the results were taken on. Each is put in
# front of PATH only where it exists, so another machine's PATH is left as it is.
for dir in /Users/work/.cargo/bin $HOME/.cargo/bin /opt/homebrew/bin; do
  [[ -d $dir ]] && PATH=$dir:$PATH
done
export PATH

# The sysl compiler: `sysl` on PATH unless SYSL names another binary.
SYSL=${SYSL:-sysl}

PROGRAMS=(nqueen matmul sudoku bedcov)

# The languages (README.md). C is the baseline of every ratio. Every program but sysl's is upstream's
# own, unmodified.
LANGS=(c rust zig swift nim d sysl)

# Where each program comes from: upstream/src/... is upstream's own file, byte-identical to the commit
# above; written/... is original, written for this benchmark (sysl only, which upstream lacks). A pair
# with no entry has no upstream program (Zig has only nqueen and matmul) and is reported as absent.
# This table is the one place provenance is decided.
typeset -A SRC
for lang ext in c c rust rs swift swift nim nim d d; do
  for prog in nqueen matmul sudoku bedcov; do
    SRC[$lang:$prog]=upstream/src/$lang/$prog.$ext
  done
done
SRC[zig:nqueen]=upstream/src/zig/nqueen.zig
SRC[zig:matmul]=upstream/src/zig/matmul.zig
for prog in nqueen matmul sudoku bedcov; do
  SRC[sysl:$prog]=written/sysl/$prog.sysl
done

provenance() {
  case ${SRC[$1:$2]} in
    upstream/*) print upstream ;;
    written/*)  print written ;;
    *)          print absent ;;
  esac
}

exe() { print -r -- $BUILD/bin/$1/$2; }

# BENCH_LANGS / BENCH_PROGRAMS name a subset (default: all).
(( ${+BENCH_LANGS} )) && LANGS=(${=BENCH_LANGS})
(( ${+BENCH_PROGRAMS} )) && PROGRAMS=(${=BENCH_PROGRAMS})
