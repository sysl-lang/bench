#!/bin/zsh
# Runs every benchmark once in every language at its timed size: `harness <Benchmark> 1 <inner>`.
# The harness checks the benchmark's own result (upstream's verify_result) and exits 1 with
# "Benchmark failed with incorrect result" on a wrong one, as upstream's harness does.
# Usage: verify.zsh [benchmark...]. Exits 1 if any run fails.

source ${0:A:h}/config.zsh
names=($@)
(( $#names )) || names=($BENCHMARKS)
failures=0
mkdir -p $BUILD/verify

for bench in $names; do
  for lang in $LANGS; do
    out=$BUILD/verify/$lang-$bench.log
    if $(harness_of $lang) $bench 1 $INNER[$bench] >$out 2>&1 && grep -q "^$bench: iterations=1 runtime: " $out; then
      printf "ok       %-10s %-5s %s\n" $bench $lang "$(grep -m1 'runtime:' $out | sed 's/.*runtime: //')"
    else
      print "WRONG    $bench $lang (see build/verify/$lang-$bench.log)"
      failures=$((failures + 1))
    fi
  done
done

(( failures == 0 ))
