#!/bin/zsh
# Builds every program in every language into build/<program>/<language>,
# then generates the standard input for k-nucleotide and reverse-complement.
# Each failure is reported and the build exits non-zero at the end.

source ${0:A:h}/lib.zsh
cd $ROOT

# Optional arguments name the languages to build (default: all); the c build is always needed
# for the knucleotide/revcomp input, so name it too when it is not already built.
(( $# )) && LANGS=($@)

# pidigits computes with GMP (README, the rules): its directories from pkg-config, and each compiler's
# spelling of them. No other program gets these.
GMP_INCLUDE=$(pkg-config --variable=includedir gmp) GMP_LIB=$(pkg-config --variable=libdir gmp)
typeset -A GMP_FLAGS
GMP_FLAGS=(c "-I$GMP_INCLUDE -L$GMP_LIB -lgmp" c-tuned "-I$GMP_INCLUDE -L$GMP_LIB -lgmp"
           cpp "-I$GMP_INCLUDE -L$GMP_LIB -lgmp" rust "-L $GMP_LIB" rust-tuned "-L $GMP_LIB"
           swift "-I programs/pidigits/swift -Xcc -I$GMP_INCLUDE -L $GMP_LIB" zig "-L$GMP_LIB -lgmp"
           odin "-extra-linker-flags:-L$GMP_LIB"
           ada "-largs -L$GMP_LIB" fortran "-L$GMP_LIB -lgmp" c3 "-L $GMP_LIB -l gmp")

# regex-redux's C, C++, Rust, Zig, Fortran and sysl-tuned programs link PCRE2 (C++ also includes Boost).
# Homebrew's copy is named outright: macOS has a libpcre2-8 of its own, built without the JIT.
PCRE2=/opt/homebrew/opt/pcre2
typeset -A PCRE2_FLAGS
PCRE2_FLAGS=(c "-I$PCRE2/include -L$PCRE2/lib -lpcre2-8" c-tuned "-I$PCRE2/include -L$PCRE2/lib -lpcre2-8"
             cpp "-I$PCRE2/include -I/opt/homebrew/opt/boost/include -L$PCRE2/lib -lpcre2-8"
             rust "-L $PCRE2/lib" rust-tuned "-L $PCRE2/lib" zig "-L$PCRE2/lib -lpcre2-8"
             fortran "-L$PCRE2/lib -lpcre2-8" sysl-tuned "--link-path $PCRE2/lib")

failed=0
for prog in $PROGRAMS; do
  mkdir -p $BUILD/$prog
  for lang in $LANGS; do
    dir=programs/$prog/$lang
    out=$BUILD/$prog/$lang
    src=${lang%-dev}   # sysl-*-dev: the same source as sysl-*, built with $SYSL_DEV
    [[ $lang == sysl-*-dev ]] && dir=programs/$prog/$src
    rm -f $out
    libs=()
    [[ $prog == pidigits ]] && libs=(${(z)GMP_FLAGS[$src]})
    [[ $prog == regexredux ]] && libs=(${(z)PCRE2_FLAGS[$src]})
    # SYSL_NO_CACHE: a build from the sources, never a replay of the run cache of either compiler.
    case $lang in
      sysl-*-dev)
              SYSL_NO_CACHE=1 SYSL_LIB=$SYSL_DEV_LIB $SYSL_DEV build --release -O3 --cpu native $libs -o $out $dir/$prog.sysl >$out.log 2>&1 ;;
      sysl-*) SYSL_NO_CACHE=1 env -u SYSL_LIB sysl build --release -O3 --cpu native $libs -o $out $dir/$prog.sysl >$out.log 2>&1 ;;
      c|c-tuned)
              clang -std=gnu17 -O3 -march=native -w -I$dir $dir/$prog.c -o $out -lm $libs >$out.log 2>&1 ;;
      cpp)    clang++ -std=c++20 -O3 -march=native -w $dir/$prog.cpp -o $out $libs >$out.log 2>&1 ;;
      rust|rust-tuned)
              rustc --crate-name bench --edition 2021 -C opt-level=3 -C target-cpu=native $dir/$prog.rs -o $out $libs >$out.log 2>&1 ;;
      swift)  swiftc -O $dir/$prog.swift -o $out $libs >$out.log 2>&1 ;;
      zig)    (cd $dir && zig build-exe -O ReleaseFast -mcpu=native -fsingle-threaded -lc --cache-dir $BUILD/.zig-cache --global-cache-dir $BUILD/.zig-global -femit-bin=$out $libs $prog.zig) >$out.log 2>&1 ;;
      nim)    nim c -d:danger --opt:speed --mm:orc --cc:clang --passC:-march=native --threads:off --hints:off --warnings:off --nimcache:$BUILD/.nimcache/$prog -o:$out $libs $dir/$prog.nim >$out.log 2>&1 ;;
      go)     go build -o $out $dir/$prog.go >$out.log 2>&1 ;;
      d)      ldc2 -O3 -release -mcpu=native -of=$out -od=$BUILD/.dobj/$prog $libs $dir/$prog.d >$out.log 2>&1 ;;
      odin)   odin build $dir/$prog.odin -file -o:speed -microarch:native -out:$out $libs >$out.log 2>&1 ;;
      ada)    mkdir -p $BUILD/.adaobj/$prog
              gnatmake -q -O3 -gnatp -march=native -D $BUILD/.adaobj/$prog -o $out $dir/$prog.adb $libs >$out.log 2>&1 ;;
      fortran) mkdir -p $BUILD/.fmod/$prog   # fortran-stdlib's hash map, which knucleotide uses
              gfortran -O3 -march=native -J $BUILD/.fmod/$prog -I$(pkg-config --variable=moduledir fortran_stdlib) -o $out $dir/$prog.f90 -L$(pkg-config --variable=libdir fortran_stdlib) -lfortran_stdlib_hashmaps -lfortran_stdlib_hash -lfortran_stdlib_core $libs >$out.log 2>&1 ;;
      c3)     c3c compile -O3 --obj-out $BUILD/.c3obj/$prog -o $out $libs $dir/$prog.c3 >$out.log 2>&1 ;;
    esac
    if [[ -x $out && -s $out ]]; then
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
elif (( ${PROGRAMS[(Ie)knucleotide]} || ${PROGRAMS[(Ie)revcomp]} )); then
  failed=1
fi

exit $failed
