# Shared definitions for build.zsh and run.zsh. Sourced, never run.

ROOT=${0:A:h:h}
export PATH=/Users/work/.cargo/bin:/opt/homebrew/bin:$PATH

PROGRAMS=(nbody spectralnorm fannkuchredux binarytrees mandelbrot fasta knucleotide revcomp)
LANGS=(sysl-idiomatic sysl-fast c rust cpp swift zig nim julia)

# Size handed to each program as its one argument. knucleotide and revcomp
# take no argument and read the generated fasta file on standard input.
typeset -A BIG SMALL
BIG=(nbody 50000000 spectralnorm 5500 fannkuchredux 11 binarytrees 18
     mandelbrot 6000 fasta 25000000 knucleotide - revcomp -)
SMALL=(nbody 1000 spectralnorm 100 fannkuchredux 7 binarytrees 10
       mandelbrot 200 fasta 1000 knucleotide - revcomp -)

# The fasta size whose output is the standard input of knucleotide and revcomp.
INPUT_N=10000000
BUILD=$ROOT/build
INPUT=$BUILD/inputs/fasta-$INPUT_N.txt

exe() { print -r -- $BUILD/$1/$2; }
