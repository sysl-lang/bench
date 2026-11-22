#!/bin/zsh
# Times the suite: INVOCATIONS processes of every benchmark in every language, each running
# `harness <Benchmark> <ITERATIONS> <inner>`. The harness times each iteration itself with a
# monotonic clock and prints "<Benchmark>: iterations=1 runtime: <n>us" (upstream's harness, read by
# ReBench's RebenchLog adapter); those lines are the measurements. Each process also runs under
# /usr/bin/time -l for its peak resident set size.
#
# Order: invocation by invocation, each benchmark in turn, the languages alternating which goes
# first, so a slow drift of the machine lands on both languages alike.
#
# Usage: run.zsh <raw dir>. Writes <raw dir>/<invocation>-<lang>-<Benchmark>.{out,time} and order.txt.

source ${0:A:h}/config.zsh
raw=${1:?raw directory}
mkdir -p $raw
uptime > $raw/load-start.txt
: > $raw/order.txt

for inv in {1..$INVOCATIONS}; do
  b=0
  for bench in $BENCHMARKS; do
    b=$((b + 1))
    order=($LANGS)
    (( (inv + b) % 2 )) && order=(${(Oa)LANGS})
    for lang in $order; do
      print -r -- "$inv $lang $bench" >> $raw/order.txt
      print -r -- "-- invocation $inv/$INVOCATIONS  $bench  $lang"
      if ! /usr/bin/time -l $(harness_of $lang) $bench $ITERATIONS $INNER[$bench] \
            >$raw/$inv-$lang-$bench.out 2>$raw/$inv-$lang-$bench.time; then
        print -u2 "FAILED $bench $lang in invocation $inv (see $raw/$inv-$lang-$bench.out)"
        exit 1
      fi
    done
  done
done

uptime > $raw/load-end.txt
