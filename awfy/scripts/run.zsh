#!/bin/zsh
# Are We Fast Yet: builds, verifies and times the suite in sysl and C++.
#
#   scripts/run.zsh build              build every language into build/ (and record the build times)
#   scripts/run.zsh verify [names...]  run each benchmark once at its standard size; the harness checks
#                                      its own result and exits non-zero on a wrong one
#   scripts/run.zsh time [n]           n invocations (default 3) of every benchmark in every language,
#                                      then results/<date>.{json,md}
#
# A run of the harness is `harness <Benchmark> <outer iterations> <inner iterations>`: the inner
# iterations are the benchmark's size (rebench.conf upstream), and each outer iteration is timed by
# the harness itself and printed as "<Benchmark>: iterations=1 runtime: <n>us". Those per-iteration
# times are what is reported; see README.md for why.

zmodload zsh/datetime

ROOT=${0:A:h:h}
BUILD=$ROOT/build
export PATH=/opt/homebrew/bin:$PATH
cd $ROOT

# No garbage-collected language (the repository README, methodology item 9): upstream's Java port is not run.
LANGS=(sysl cpp)

# A second sysl compiler to compare with the one on PATH: SYSL_DEV names its binary and SYSL_DEV_LIB
# its library/ tree. When set, the same sysl sources are also built with it, as the language sysl-dev.
[[ -n $SYSL_DEV ]] && LANGS=(sysl sysl-dev cpp)

# Each benchmark's inner iterations: upstream rebench.conf.
typeset -A INNER
INNER=(DeltaBlue 12000 Richards 100 Json 100 CD 250 Havlak 1500
       Bounce 1500 List 1500 Mandelbrot 500 NBody 250000 Permute 1000 Queens 1000 Sieve 3000
       Storage 1000 Towers 600)
BENCHMARKS=(DeltaBlue Richards Json CD Havlak Bounce List Mandelbrot NBody Permute Queens Sieve Storage Towers)

# Outer iterations per invocation, as upstream runs each executor: C++ (and so sysl) is a "slow VM"
# with 10 and no warm-up.
typeset -A OUTER WARMUP
OUTER=(sysl 10 sysl-dev 10 cpp 10)
WARMUP=(sysl 0 sysl-dev 0 cpp 0)

# The benchmarks a language cannot run yet, with the reason (README.md, "Gaps"). Empty from sysl
# 0.12.0, which the sysl sources need (`@no_fuse`, and `===` on a trait object for DeltaBlue): every
# language runs every benchmark, so no geometric mean is over a subset (AUDIT.md A5).
typeset -A SKIP
SKIP=()

# The benchmarks a sysl compiler cannot build at all: its harness is built from a copy of
# benchmarks/sysl without their files and without their arms in run.sysl. Empty from sysl 0.12.0.
typeset -A OMIT
OMIT=()

harness() {  # <lang>
  case $1 in
    sysl) print -r -- $BUILD/harness-sysl ;;
    sysl-dev) print -r -- $BUILD/harness-sysl-dev ;;
    cpp)  print -r -- $BUILD/harness-cpp ;;
  esac
}

build() {
  rm -rf $BUILD
  mkdir -p $BUILD
  local t0 failed=0

  local lang src compiler bench
  local -a lines
  for lang in ${(M)LANGS:#sysl*}; do
    src=benchmarks/sysl
    if [[ -n ${OMIT[$lang]} ]]; then
      src=$BUILD/src-$lang
      cp -R benchmarks/sysl $src
      for bench in ${=OMIT[$lang]}; do
        rm $src/${bench:l}.sysl
        lines=("${(@f)$(<$src/run.sysl)}")
        print -rl -- "${(@)lines:#*\"$bench\" -> *}" > $src/run.sysl
      done
    fi
    compiler=(env -u SYSL_LIB sysl)
    [[ $lang == sysl-dev ]] && compiler=(env SYSL_LIB=$SYSL_DEV_LIB $SYSL_DEV)
    ${compiler[-1]} --version > $BUILD/$lang.version
    # SYSL_NO_CACHE: a build from the sources, not a replay of the run cache.
    t0=$EPOCHREALTIME
    if (cd $src && SYSL_NO_CACHE=1 $compiler build --release -O3 --cpu native -o $BUILD/harness-$lang .) >$BUILD/$lang.log 2>&1; then
      print -r -- "$(( EPOCHREALTIME - t0 ))" > $BUILD/$lang.build-seconds
      print "built  $lang ($(<$BUILD/$lang.build-seconds) s)"
    else
      print "FAILED $lang (see build/$lang.log)"; failed=1
    fi
  done

  # Upstream build.sh: OPT='-O3 -flto -march=native', COMP_OPT='-ffp-contract=off -std=c++17'.
  # -mcpu=native where upstream says -march=native: on arm64 Apple clang -march=native means
  # apple-m1, and -mcpu=native is this machine's processor, as sysl's --cpu native is (AUDIT.md A1).
  t0=$EPOCHREALTIME
  if (cd benchmarks/C++ && clang++ -Wall -Wextra -Wno-unused-private-field -O3 -flto -mcpu=native \
        -ffp-contract=off -std=c++17 src/harness.cpp src/deltablue.cpp src/memory/object_tracker.cpp \
        src/richards.cpp -o $BUILD/harness-cpp) >$BUILD/cpp.log 2>&1; then
    print -r -- "$(( EPOCHREALTIME - t0 ))" > $BUILD/cpp.build-seconds
    print "built  cpp ($(<$BUILD/cpp.build-seconds) s)"
  else
    print "FAILED cpp (see build/cpp.log)"; failed=1
  fi

  return $failed
}

verify() {
  local failures=0 names=($@)
  (( $#names )) || names=($BENCHMARKS)
  for bench in $names; do
    for lang in $LANGS; do
      if [[ -n ${SKIP[$lang:$bench]} ]]; then
        print "skip     $bench/$lang (${SKIP[$lang:$bench]})"
        continue
      fi
      local out=$BUILD/verify-$lang-$bench.log
      if ${=$(harness $lang)} $bench 1 $INNER[$bench] >$out 2>&1; then
        print "ok       $bench/$lang  $(grep -m1 'runtime:' $out | sed 's/.*runtime: //')"
      else
        print "WRONG    $bench/$lang (see ${out#$ROOT/})"
        failures=$((failures + 1))
      fi
    done
  done
  (( failures == 0 ))
}

time_all() {
  local invocations=${1:-3} stamp=$(date +%Y-%m-%d) raw
  raw=$ROOT/results/.raw-$stamp
  rm -rf $raw
  mkdir -p $raw
  uptime > $raw/load-start.txt
  for lang in $LANGS; do
    [[ -f $BUILD/$lang.build-seconds ]] && cp $BUILD/$lang.build-seconds $raw/
  done
  for lang in ${(M)LANGS:#sysl*} cpp; do
    stat -f %z $BUILD/harness-$lang > $raw/$lang.binary-bytes
  done
  for lang in ${(M)LANGS:#sysl*}; do
    [[ -f $BUILD/$lang.version ]] && cp $BUILD/$lang.version $raw/
  done

  for bench in $BENCHMARKS; do
    for lang in $LANGS; do
      [[ -n ${SKIP[$lang:$bench]} ]] && continue
      for i in {1..$invocations}; do
        print -- "-- $bench/$lang #$i"
        # /usr/bin/time -l adds the peak resident set size to stderr.
        if ! /usr/bin/time -l ${=$(harness $lang)} $bench $OUTER[$lang] $INNER[$bench] \
              >$raw/$lang-$bench-$i.out 2>$raw/$lang-$bench-$i.time; then
          print "FAILED $bench/$lang"; return 1
        fi
      done
    done
  done

  uptime > $raw/load-end.txt
  python3 -I scripts/report.py $raw $stamp ${(kv)WARMUP} && rm -rf $raw
}

case $1 in
  build)  build ;;
  verify) verify ${@:2} ;;
  time)   time_all $2 ;;
  *)      sed -n '2,12p' $0; exit 1 ;;
esac
