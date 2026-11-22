#!/bin/zsh
# Checks that every upstream file kept in awfy/ is byte-identical to upstream at the pinned commit
# (build/upstream, which setup.zsh checks out), and that the sysl port's Json document is the Java
# port's, character for character. Prints one line per check; exits 1 if any differs.

source ${0:A:h}/config.zsh
cd $AWFY_ROOT

if [[ $(git -C $UPSTREAM_DIR rev-parse HEAD 2>/dev/null) != $UPSTREAM_COMMIT ]]; then
  print -u2 "build/upstream is not at $UPSTREAM_COMMIT; run scripts/setup.zsh"
  exit 1
fi

# build.sh's outputs (`harness`, `harness-<CXX><OPT>`), which upstream's own .gitignore ignores, are
# not compared: they are in the upstream checkout once C++ is built. Narrower than upstream's
# `/harness*`, since diff -x matches a name at any depth and src/harness.cpp must still be compared.
skip=(-x harness -x 'harness-*')
differ=0
for pair in $UPSTREAM_FILES; do
  here=${pair%%=*} there=${pair#*=}
  if diff -r $skip $here $UPSTREAM_DIR/$there >/dev/null; then
    print "same     $here  =  upstream $there"
  else
    print "DIFFERS  $here  vs  upstream $there"
    diff -r $skip $here $UPSTREAM_DIR/$there | head -20
    differ=1
  fi
done

# The Json benchmark parses one document, which upstream writes as a string literal in each port.
# The sysl port's is generated from the Java port's line; the two literals must be equal.
java_line=$(sed -n 39p $UPSTREAM_DIR/benchmarks/Java/src/Json.java)
sysl_line=$(sed -n 4p benchmarks/sysl/json_data.sysl)
java_doc=${${java_line#*rapBenchmarkMinified = }%;}
sysl_doc=${sysl_line#const rap_benchmark_minified = }
if [[ $java_line == *rapBenchmarkMinified* && $sysl_line == const\ rap_benchmark_minified* && $java_doc == $sysl_doc ]]; then
  print "same     benchmarks/sysl/json_data.sysl  =  upstream benchmarks/Java/src/Json.java:39 (${#java_doc} characters)"
else
  print "DIFFERS  benchmarks/sysl/json_data.sysl  vs  upstream benchmarks/Java/src/Json.java:39"
  differ=1
fi

# The Rust port's literal is the Java port's line too, written as a Rust string.
rust_line=$(sed -n 4p benchmarks/Rust/src/json_data.rs)
rust_doc=${${rust_line#pub const RAP_BENCHMARK_MINIFIED: &str = }%;}
if [[ $rust_line == pub\ const\ RAP_BENCHMARK_MINIFIED* && $java_doc == $rust_doc ]]; then
  print "same     benchmarks/Rust/src/json_data.rs  =  upstream benchmarks/Java/src/Json.java:39 (${#java_doc} characters)"
else
  print "DIFFERS  benchmarks/Rust/src/json_data.rs  vs  upstream benchmarks/Java/src/Json.java:39"
  differ=1
fi

exit $differ
