# The optimisation flags of each language, one table read by build.zsh and recorded in the results.
# Sourced, never run. METHODOLOGY.md justifies each line.
#
# Upstream's languages take upstream's flags exactly, from src/<lang>/Makefile at the vendored commit:
#   c      CFLAGS=-O3 -fwrapv -flto              (src/c/Makefile; $(CC) is cc)
#   rust   RUST_FLAGS=-C debuginfo=0 -C opt-level=3
#   swift  SWIFTC_FLAGS=-Ounchecked
#   zig    ZIG_FLAGS=-O ReleaseFast
#   nim    NIM_FLAGS=-d:release -d:lto --bound_checks:off --overflow_checks:off -d:nimEmulateOverflowChecks
#   d      DFLAGS=-O3 -release                   ($(LDC) is ldc2)
# sysl, which upstream lacks, takes C's: -O3 and full LTO, and --release, whose integer arithmetic
# wraps as C's does under -fwrapv. No upstream Makefile names a processor, so neither does sysl's.

typeset -A FLAGS
FLAGS=(
  c      "-O3 -fwrapv -flto"
  rust   "-C debuginfo=0 -C opt-level=3"
  swift  "-Ounchecked"
  zig    "-O ReleaseFast"
  nim    "-d:release -d:lto --bound_checks:off --overflow_checks:off -d:nimEmulateOverflowChecks"
  d      "-O3 -release"
  sysl   "--release -O3 --lto full"
)
