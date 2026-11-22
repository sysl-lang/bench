#!/bin/zsh
# Checks that the sysl port, and the Zig and C ports when LANGS holds them, frees everything it allocates
# (upstream's C++ rule: "benchmarks have to run without memory leaks"). Builds the sysl harness with sysl's counted heap (SYSL_COUNT_ALLOCS=1),
# which reports a non-zero net count of allocations on stderr at exit, and runs every benchmark once
# at its timed size. Not part of a timing run; the counted heap is slower.

source ${0:A:h}/config.zsh
mkdir -p $BUILD/leaks
(cd $AWFY_ROOT/benchmarks/sysl && env -u SYSL_LIB SYSL_NO_CACHE=1 SYSL_COUNT_ALLOCS=1 $SYSL build $SYSL_FLAGS --cc $CLANG -o $BUILD/leaks/harness-counted .) >$BUILD/leaks/build.log 2>&1 ||
  { print "FAILED   counted build (see build/leaks/build.log)"; exit 1 }

failures=0
for bench in $BENCHMARKS; do
  err=$BUILD/leaks/$bench.err
  if $BUILD/leaks/harness-counted $bench 1 $INNER[$bench] >/dev/null 2>$err && [[ ! -s $err ]]; then
    print "no leak  $bench"
  else
    print "LEAK     $bench: $(head -3 $err)"
    failures=$((failures + 1))
  fi
done

# Zig, when it is one of the languages run: a Debug build allocates through DebugAllocator, and the
# harness exits 1 with "memory leaked" when anything is still live at exit. Debug keeps every safety
# check, so the sizes are small: one inner iteration, CD 10 and DeltaBlue 20 (their smallest that
# reach every path of the benchmark).
if (( ${LANGS[(Ie)zig]} )); then
  typeset -A SMALL
  SMALL=(CD 10 DeltaBlue 20)
  (cd $AWFY_ROOT/benchmarks/Zig && $ZIG build-exe -O debug -lc --cache-dir $BUILD/zig-cache -femit-bin=$BUILD/leaks/harness-zig-debug harness.zig) >$BUILD/leaks/zig-build.log 2>&1 ||
    { print "FAILED   zig debug build (see build/leaks/zig-build.log)"; exit 1 }
  for bench in $BENCHMARKS; do
    err=$BUILD/leaks/zig-$bench.err
    if $BUILD/leaks/harness-zig-debug $bench 1 ${SMALL[$bench]:-1} >/dev/null 2>$err; then
      print "no leak  $bench zig"
    else
      print "LEAK     $bench zig: $(head -3 $err)"
      failures=$((failures + 1))
    fi
  done
fi

# C, when it is one of the languages run, at the same small sizes. Two builds, because Apple's
# AddressSanitizer has no leak detector on macOS: an ASan build catches use-after-free, double free
# and overflow; a plain debug build runs under macOS `leaks --atExit`, which exits 1 when any block is
# unreachable at exit.
if (( ${LANGS[(Ie)c]} )); then
  typeset -A SMALL
  SMALL=(CD 10 DeltaBlue 20)
  CC=$CLANG OPT='-O1 -g -fsanitize=address -fno-omit-frame-pointer' bash $AWFY_ROOT/benchmarks/C/build.sh $BUILD/leaks/harness-c-asan >$BUILD/leaks/c-build.log 2>&1 &&
    CC=$CLANG OPT='-O0 -g' bash $AWFY_ROOT/benchmarks/C/build.sh $BUILD/leaks/harness-c-debug >>$BUILD/leaks/c-build.log 2>&1 ||
    { print "FAILED   c debug builds (see build/leaks/c-build.log)"; exit 1 }
  for bench in $BENCHMARKS; do
    err=$BUILD/leaks/c-$bench.err
    if $BUILD/leaks/harness-c-asan $bench 1 ${SMALL[$bench]:-1} >/dev/null 2>$err &&
       leaks --atExit -- $BUILD/leaks/harness-c-debug $bench 1 ${SMALL[$bench]:-1} >$err 2>&1; then
      print "no leak  $bench c  ($(grep -m1 'leaks for' $err))"
    else
      print "LEAK     $bench c: $(grep -m3 'ERROR\|leaks for\|Leak:' $err)"
      failures=$((failures + 1))
    fi
  done
fi
(( failures == 0 ))
