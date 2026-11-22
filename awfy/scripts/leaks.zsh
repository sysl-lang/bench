#!/bin/zsh
# Checks that the sysl port frees everything it allocates (upstream's C++ rule: "benchmarks have to
# run without memory leaks"). Builds the sysl harness with sysl's counted heap (SYSL_COUNT_ALLOCS=1),
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
(( failures == 0 ))
