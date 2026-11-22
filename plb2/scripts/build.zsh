#!/bin/zsh
# Builds every program in every language into build/bin/<program>/<language>, each with its build log
# beside it (<language>.log). A program upstream does not have is skipped and said so. A build that
# fails is reported with the head of its log; the run carries on, and build/status.tsv records every
# cell (built, failed or absent) for verify.py, time.zsh and report.py.
#
# The commands are upstream's own (its Makefile for the language), mapped to this machine only by an
# output path and a cache or object directory under build/. scripts/flags.zsh holds the flags.

source ${0:A:h}/lib.zsh
source ${0:A:h}/flags.zsh
cd $PLB2

mkdir -p $BUILD
table=$BUILD/status.tsv
print -r -- $'program\tlanguage\tstatus\tsource' >$table
failed=0

for prog in $PROGRAMS; do
  mkdir -p $BUILD/bin/$prog
  for lang in $LANGS; do
    src=${SRC[$lang:$prog]}
    if [[ -z $src ]]; then
      print "absent $prog/$lang (upstream has no $lang $prog)"
      print -r -- "$prog"$'\t'"$lang"$'\tabsent\t-' >>$table
      continue
    fi
    out=$(exe $prog $lang)
    log=$out.log
    rm -f $out $log
    flags=(${(z)FLAGS[$lang]})
    case $lang in
      c)     cc $flags -o $out $src >$log 2>&1 ;;
      rust)  rustc $flags -o $out $src >$log 2>&1 ;;
      swift) swiftc $flags -module-cache-path $BUILD/swift/cache -o $out $src >$log 2>&1 ;;
      zig)   zig build-exe $flags --cache-dir $BUILD/zig/cache --global-cache-dir $BUILD/zig/global \
               -femit-bin=$out $src >$log 2>&1 ;;
      nim)   nim c $flags --nimcache:$BUILD/nim/$prog -o:$out $src >$log 2>&1 ;;
      d)     ldc2 $flags -od=$BUILD/d/$prog -of=$out $src >$log 2>&1 ;;
      sysl)  SYSL_NO_CACHE=1 $SYSL build $flags -o $out $src >$log 2>&1 ;;
    esac
    if [[ -x $out && -s $out ]]; then
      print "built  $prog/$lang"
      print -r -- "$prog"$'\t'"$lang"$'\tbuilt\t'"$src" >>$table
    else
      print "FAILED $prog/$lang (build/bin/$prog/$lang.log)"
      sed 's/^/       | /' $log | head -20
      print -r -- "$prog"$'\t'"$lang"$'\tfailed\t'"$src" >>$table
      failed=1
    fi
  done
done
exit $failed
