#!/bin/zsh
# Builds every program in every language into build/bin/<program>/<language>, each with its build log
# beside it. Every failure is reported and the script exits non-zero at the end.
#
# The commands are upstream's own (its Makefile for the language, METHODOLOGY.md §4), mapped to this
# machine only by an output path (-o and the like) and a cache or module directory under build/. A
# language upstream has no Makefile for gets the flags METHODOLOGY.md §4 justifies. scripts/flags.zsh
# prints the same table for the results file.

source ${0:A:h}/lib.zsh
source ${0:A:h}/flags.zsh
cd $PLB2

failed=0
for prog in $PROGRAMS; do
  mkdir -p $BUILD/bin/$prog
  for lang in $LANGS; do
    src=${SRC[$lang:$prog]}
    out=$(exe $prog $lang)
    log=$out.log
    rm -f $out $log
    flags=(${(z)FLAGS[$lang]})
    case $lang in
      c)       cc $flags -o $out $src >$log 2>&1 ;;
      cpp)     c++ $flags -o $out $src >$log 2>&1 ;;
      rust)    rustc $flags -o $out $src >$log 2>&1 ;;
      go)      (cd ${src:h} && go build $flags -o $out ${src:t}) >$log 2>&1 ;;
      swift)   mkdir -p $BUILD/swift/$prog
               swiftc $flags -module-cache-path $BUILD/swift/cache -o $out $src >$log 2>&1 ;;
      zig)     zig build-exe $flags --cache-dir $BUILD/zig/cache --global-cache-dir $BUILD/zig/global \
                 -femit-bin=$out $src >$log 2>&1 ;;
      fortran) mkdir -p $BUILD/fortran/$prog
               gfortran $flags -J $BUILD/fortran/$prog -o $out $src >$log 2>&1 ;;
      ada)     mkdir -p $BUILD/ada/$prog
               gnatmake $flags -D $BUILD/ada/$prog -o $out $src >$log 2>&1 ;;
      odin)    odin build $src -file $flags -out:$out >$log 2>&1 ;;
      c3)      c3c compile $flags --obj-out $BUILD/c3/$prog -o $out $src >$log 2>&1 ;;
      sysl)    SYSL_NO_CACHE=1 sysl build $flags -o $out $src >$log 2>&1 ;;
    esac
    if [[ -x $out && -s $out ]]; then
      print "built  $prog/$lang"
    else
      print "FAILED $prog/$lang (build/bin/$prog/$lang.log)"
      sed 's/^/       | /' $log | head -20
      failed=1
    fi
  done
done
exit $failed
