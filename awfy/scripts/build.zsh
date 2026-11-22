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

# Zig: only when it is one of the languages run.
if (( ${LANGS[(Ie)zig]} )); then
  t0=$EPOCHREALTIME
  print -r -- "(cd benchmarks/Zig && zig build-exe ${ZIG_FLAGS[*]} -femit-bin=<build>/harness-zig harness.zig)" > $BUILD/zig.command
  if (cd $AWFY_ROOT/benchmarks/Zig && $ZIG build-exe $ZIG_FLAGS --cache-dir $BUILD/zig-cache -femit-bin=$BUILD/harness-zig harness.zig) >$BUILD/zig.log 2>&1; then
    print -r -- $(( EPOCHREALTIME - t0 )) > $BUILD/zig.build-seconds
    printf "built    zig   %6.1f s  zig %s\n" $(<$BUILD/zig.build-seconds) "$($ZIG version)"
  else
    print "FAILED   zig (see build/zig.log)"; failed=1
  fi
fi

# C: only when it is one of the languages run. The C++ column's clang and OPT.
if (( ${LANGS[(Ie)c]} )); then
  t0=$EPOCHREALTIME
  print -r -- "(cd benchmarks/C && CC=clang OPT='$C_OPT' bash ./build.sh <build>/harness-c)" > $BUILD/c.command
  if CC=$CLANG OPT=$C_OPT bash $AWFY_ROOT/benchmarks/C/build.sh $BUILD/harness-c >$BUILD/c.log 2>&1; then
    print -r -- $(( EPOCHREALTIME - t0 )) > $BUILD/c.build-seconds
    printf "built    c     %6.1f s\n" $(<$BUILD/c.build-seconds)
  else
    print "FAILED   c (see build/c.log)"; failed=1
  fi
fi

# Rust: only when it is one of the languages run. --locked builds from the committed Cargo.lock (the
# crate has no dependencies); CARGO_HOME and the target directory stay under build/.
if (( ${LANGS[(Ie)rust]} )); then
  t0=$EPOCHREALTIME
  print -r -- "(cd benchmarks/Rust && RUSTFLAGS='$RUSTFLAGS_AWFY' cargo build --release --locked && cp target/release/harness <build>/harness-rust)" > $BUILD/rust.command
  if (cd $AWFY_ROOT/benchmarks/Rust && CARGO_HOME=$BUILD/cargo-home RUSTC=${CARGO:h}/rustc RUSTFLAGS=$RUSTFLAGS_AWFY \
        $CARGO build --release --locked --target-dir $BUILD/rust-target) >$BUILD/rust.log 2>&1 &&
     cp $BUILD/rust-target/release/harness $BUILD/harness-rust; then
    print -r -- $(( EPOCHREALTIME - t0 )) > $BUILD/rust.build-seconds
    printf "built    rust  %6.1f s  %s\n" $(<$BUILD/rust.build-seconds) "$(${CARGO:h}/rustc --version)"
  else
    print "FAILED   rust (see build/rust.log)"; failed=1
  fi
fi

exit $failed
