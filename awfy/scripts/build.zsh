#!/bin/zsh
# Builds each port: C++ with upstream's own build.sh in the upstream checkout, sysl with `sysl build`.
# Writes build/<lang>.log, build/<lang>.build-seconds and build/<lang>.command.

source ${0:A:h}/config.zsh
zmodload zsh/datetime
failed=0

[[ -d $UPSTREAM_DIR/.git ]] || { print -u2 "no build/upstream; run scripts/setup.zsh"; exit 1 }
mkdir -p $BUILD

# C++: upstream's build.sh, unmodified, with its two documented knobs: CXX (the compiler) and OPT.
# It builds harness-<CXX><OPT> in benchmarks/C++ and links `harness` to it. CXX is a bare name on
# PATH because build.sh puts it in the binary's file name.
t0=$EPOCHREALTIME
cmd="CXX=${CLANGXX:t} OPT='$CPP_OPT' bash ./build.sh"
print -r -- "(cd benchmarks/C++ && PATH=${CLANGXX:h}:\$PATH $cmd)" > $BUILD/cpp.command
rm -f $UPSTREAM_DIR/benchmarks/C++/harness*(N)
if (cd $UPSTREAM_DIR/benchmarks/C++ && PATH=${CLANGXX:h}:$PATH CXX=${CLANGXX:t} OPT=$CPP_OPT bash ./build.sh) >$BUILD/cpp.log 2>&1 &&
   [[ -x $UPSTREAM_DIR/benchmarks/C++/harness ]]; then
  print -r -- $(( EPOCHREALTIME - t0 )) > $BUILD/cpp.build-seconds
  printf "built    cpp   %6.1f s  %s\n" $(<$BUILD/cpp.build-seconds) "$(grep -m1 'Binary name' $BUILD/cpp.log)"
else
  print "FAILED   cpp (see build/cpp.log)"; failed=1
fi

# sysl: SYSL_NO_CACHE so the build is made from the sources, not replayed from sysl's run cache.
t0=$EPOCHREALTIME
print -r -- "(cd benchmarks/sysl && SYSL_NO_CACHE=1 sysl build ${SYSL_FLAGS[*]} --cc $CLANG -o <build>/harness-sysl .)" > $BUILD/sysl.command
if (cd $AWFY_ROOT/benchmarks/sysl && env -u SYSL_LIB SYSL_NO_CACHE=1 $SYSL build $SYSL_FLAGS --cc $CLANG -o $BUILD/harness-sysl .) >$BUILD/sysl.log 2>&1; then
  print -r -- $(( EPOCHREALTIME - t0 )) > $BUILD/sysl.build-seconds
  printf "built    sysl  %6.1f s\n" $(<$BUILD/sysl.build-seconds)
else
  print "FAILED   sysl (see build/sysl.log)"; failed=1
fi

exit $failed
