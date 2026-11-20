# The optimisation flags of each language, one table read by build.zsh and recorded in the results.
# Sourced, never run. METHODOLOGY.md §4 justifies each line.
#
# Upstream's languages take upstream's flags exactly, from src/<lang>/Makefile at the vendored commit:
#   c        CFLAGS=-O3 -fwrapv -flto              (src/c/Makefile; $(CC) is cc)
#   rust     RUST_FLAGS=-C debuginfo=0 -C opt-level=3
#   go       go build                              (no flags)
#   swift    SWIFTC_FLAGS=-Ounchecked
#   zig      ZIG_FLAGS=-O ReleaseFast
#   fortran  FFLAGS=-O3                            ($(FC) is gfortran)
# A language upstream does not have takes its compiler's release optimisation, as the rest of this
# bench builds it, at the level upstream's C uses (-O3) where the compiler has levels, and no
# processor option, because no upstream Makefile names one.

typeset -A FLAGS
FLAGS=(
  c        "-O3 -fwrapv -flto"
  cpp      "-std=c++20 -O3 -fwrapv -flto"
  rust     "-C debuginfo=0 -C opt-level=3"
  go       ""
  swift    "-Ounchecked"
  zig      "-O ReleaseFast"
  fortran  "-O3"
  ada      "-q -O3 -gnatp"
  odin     "-o:speed"
  c3       "-O3"
  sysl     "--release -O3 --lto full"
)
