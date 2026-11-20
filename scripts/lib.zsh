# Shared definitions for build.zsh and run.zsh. Sourced, never run.

ROOT=${0:A:h:h}
export PATH=$HOME/.local/gnat-16.1.0/bin:/Users/work/.cargo/bin:/opt/homebrew/bin:$PATH

PROGRAMS=(nbody spectralnorm fannkuchredux binarytrees mandelbrot fasta knucleotide revcomp)
# Only languages that run with no garbage collector (README, methodology item 9).
LANGS=(sysl-idiomatic sysl-tuned c c-tuned rust rust-tuned cpp swift zig odin c3 ada fortran)

# A second sysl compiler to compare with the one on PATH: SYSL_DEV names its binary and SYSL_DEV_LIB
# its library/ tree. When set, every program is also built from its sysl-idiomatic and sysl-tuned
# sources with that compiler, as the columns sysl-idiomatic-dev and sysl-tuned-dev.
if [[ -n $SYSL_DEV ]]; then
  LANGS=(sysl-idiomatic sysl-tuned sysl-idiomatic-dev sysl-tuned-dev ${LANGS:#sysl-*})
fi

# Size handed to each program as its one argument. A program whose size is -
# (knucleotide, revcomp, regexredux) takes no argument and reads the generated
# fasta file on standard input.
typeset -A BIG SMALL
BIG=(nbody 50000000 spectralnorm 5500 fannkuchredux 11 binarytrees 18
     mandelbrot 6000 fasta 25000000 knucleotide - revcomp -)
SMALL=(nbody 1000 spectralnorm 100 fannkuchredux 7 binarytrees 10
       mandelbrot 200 fasta 1000 knucleotide - revcomp -)

# regex-redux reads the same fasta file as knucleotide and revcomp.
PROGRAMS+=(regexredux)
BIG+=(regexredux -)
SMALL+=(regexredux -)

# pidigits: the Benchmarks Game's 10000 digits, and its 27-digit reference output.
PROGRAMS+=(pidigits)
BIG[pidigits]=10000
SMALL[pidigits]=27

# Programs that do not finish at the timed size, with the reason. They are verified at the small size
# only, are not timed, and show as DNF in the report (which reads the same table from BENCH_DNF).
typeset -A DNF
DNF=(regexredux:sysl-idiomatic "sysl.regex replace_all is quadratic (FINDINGS.md §9): not finished in hours at the timed size"
     regexredux:sysl-idiomatic-dev "sysl.regex replace_all is quadratic (FINDINGS.md §9): not finished in hours at the timed size")
export BENCH_DNF=${(j:,:)${(k)DNF}}

# BENCH_PROGRAMS names a subset to build or verify (default: every program).
(( ${+BENCH_PROGRAMS} )) && PROGRAMS=(${=BENCH_PROGRAMS})

# The fasta size whose output is the standard input of knucleotide, revcomp and regexredux.
INPUT_N=10000000
BUILD=$ROOT/build
INPUT=$BUILD/inputs/fasta-$INPUT_N.txt

# reverse-complement reads the Benchmarks Game's own size, fasta 25,000,000 (about 254 MB): at
# 10,000,000 its fastest programs finish in about 30 ms, where a process's start-up (3 to 4 ms for
# /usr/bin/true here) is a tenth of the time and its differences between languages move the ratios
# (AUDIT.md A7).
REVCOMP_N=25000000
REVCOMP_INPUT=$BUILD/inputs/fasta-$REVCOMP_N.txt

exe() { print -r -- $BUILD/$1/$2; }

# The standard input a program whose size is - reads at the timed size.
input_for() { [[ $1 == revcomp ]] && print -r -- $REVCOMP_INPUT || print -r -- $INPUT; }
