#!/bin/zsh
# Builds every program in every language into build/<program>/<language>,
# then generates the standard input for k-nucleotide and reverse-complement.
# Each failure is reported and the build exits non-zero at the end.

source ${0:A:h}/lib.zsh
cd $ROOT

failed=0
for prog in $PROGRAMS; do
  mkdir -p $BUILD/$prog
  for lang in $LANGS; do
    dir=programs/$prog/$lang
    out=$BUILD/$prog/$lang
    rm -f $out
    case $lang in
      sysl-*) sysl build --release -O3 -o $out $dir/$prog.sysl >$out.log 2>&1 ;;
      c)      clang -std=gnu17 -O3 -march=native -w -I$dir $dir/$prog.c -o $out -lm >$out.log 2>&1 ;;
      cpp)    clang++ -std=c++20 -O3 -march=native -w $dir/$prog.cpp -o $out >$out.log 2>&1 ;;
      rust)   rustc --crate-name bench --edition 2021 -C opt-level=3 -C target-cpu=native $dir/$prog.rs -o $out >$out.log 2>&1 ;;
      swift)  swiftc -O $dir/$prog.swift -o $out >$out.log 2>&1 ;;
    esac
    if [[ -x $out ]]; then
      print "built  $prog/$lang"
    else
      print "FAILED $prog/$lang (see build/$prog/$lang.log)"
      failed=1
    fi
  done
done

mkdir -p $BUILD/inputs
if [[ -x $(exe fasta c) ]]; then
  $(exe fasta c) $INPUT_N > $INPUT
  print "input  $INPUT ($(wc -c < $INPUT) bytes)"
else
  failed=1
fi

exit $failed
