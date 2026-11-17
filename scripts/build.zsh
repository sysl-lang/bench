#!/bin/zsh
# Builds every program in every language into build/<program>/<language>,
# then generates the standard input for k-nucleotide and reverse-complement.
# Each failure is reported and the build exits non-zero at the end.

source ${0:A:h}/lib.zsh
cd $ROOT

# Optional arguments name the languages to build (default: all); the c build is always needed
# for the knucleotide/revcomp input, so name it too when it is not already built.
(( $# )) && LANGS=($@)

failed=0
for prog in $PROGRAMS; do
  mkdir -p $BUILD/$prog
  for lang in $LANGS; do
    dir=programs/$prog/$lang
    out=$BUILD/$prog/$lang
    [[ $lang == eiffel-contracts ]] && dir=programs/$prog/eiffel   # the same source, built with assertions on
    rm -f $out
    case $lang in
      sysl-*) sysl build --release -O3 --cpu native -o $out $dir/$prog.sysl >$out.log 2>&1 ;;
      c|c-tuned)
              clang -std=gnu17 -O3 -march=native -w -I$dir $dir/$prog.c -o $out -lm >$out.log 2>&1 ;;
      cpp)    clang++ -std=c++20 -O3 -march=native -w $dir/$prog.cpp -o $out >$out.log 2>&1 ;;
      rust|rust-tuned)
              rustc --crate-name bench --edition 2021 -C opt-level=3 -C target-cpu=native $dir/$prog.rs -o $out >$out.log 2>&1 ;;
      swift)  swiftc -O $dir/$prog.swift -o $out >$out.log 2>&1 ;;
      zig)    (cd $dir && zig build-exe -O ReleaseFast -mcpu=native -fsingle-threaded -lc --cache-dir $BUILD/.zig-cache --global-cache-dir $BUILD/.zig-global -femit-bin=$out $prog.zig) >$out.log 2>&1 ;;
      nim)    nim c -d:danger --opt:speed --mm:orc --cc:clang --passC:-march=native --threads:off --hints:off --warnings:off --nimcache:$BUILD/.nimcache/$prog -o:$out $dir/$prog.nim >$out.log 2>&1 ;;
      go)     go build -o $out $dir/$prog.go >$out.log 2>&1 ;;
      d)      ldc2 -O3 -release -mcpu=native -of=$out -od=$BUILD/.dobj/$prog $dir/$prog.d >$out.log 2>&1 ;;
      odin)   odin build $dir/$prog.odin -file -o:speed -microarch:native -out:$out >$out.log 2>&1 ;;
      ada)    mkdir -p $BUILD/.adaobj/$prog
              gnatmake -q -O3 -gnatp -march=native -D $BUILD/.adaobj/$prog -o $out $dir/$prog.adb >$out.log 2>&1 ;;
      fortran) mkdir -p $BUILD/.fmod/$prog   # fortran-stdlib's hash map, which knucleotide uses
              gfortran -O3 -march=native -J $BUILD/.fmod/$prog -I$(pkg-config --variable=moduledir fortran_stdlib) -o $out $dir/$prog.f90 -L$(pkg-config --variable=libdir fortran_stdlib) -lfortran_stdlib_hashmaps -lfortran_stdlib_hash -lfortran_stdlib_core >$out.log 2>&1 ;;
      c3)     c3c compile -O3 --obj-out $BUILD/.c3obj/$prog -o $out $dir/$prog.c3 >$out.log 2>&1 ;;
      eiffel|eiffel-contracts)
              # EiffelStudio's finalized (optimised) build. The .ecf has a `release` target with
              # every assertion off and a `contracts` target with them all on; both inline
              # (`inlining` true, `inlining_size` 100), as a finalized release build should.
              target=release
              [[ $lang == eiffel-contracts ]] && target=contracts
              rm -rf $BUILD/.eifgen/$prog/$lang
              ec -batch -finalize -config $dir/$prog.ecf -target $target -project_path $BUILD/.eifgen/$prog/$lang -c_compile >$out.log 2>&1
              cp $BUILD/.eifgen/$prog/$lang/EIFGENs/$target/F_code/$prog $out 2>>$out.log ;;
      java)   # The JVM runs bytecode: the "executable" is a launcher, so every timed run
              # includes JVM startup and JIT warm-up, as on the Benchmarks Game.
              mkdir -p $BUILD/.jclasses/$prog
              if javac -d $BUILD/.jclasses/$prog $dir/$prog.java >$out.log 2>&1; then
                printf '#!/bin/sh\nexec java -cp %s %s "$@"\n' $BUILD/.jclasses/$prog $prog > $out
                chmod +x $out
              fi ;;
      julia)  # Julia is JIT-compiled: the "executable" is a launcher, so every timed run
              # includes Julia's startup and compilation, as on the Benchmarks Game.
              printf '#!/bin/sh\nexec julia -O3 --check-bounds=no --startup-file=no %s "$@"\n' $ROOT/$dir/$prog.jl > $out
              chmod +x $out ;;
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
else
  failed=1
fi

exit $failed
