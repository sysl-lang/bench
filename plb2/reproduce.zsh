#!/bin/zsh
# Reproduces plb2's results from nothing but this folder and the toolchains: builds every program,
# checks every output against upstream C's, times them and writes results/report.md and
# results/report.html. README.md "Reproducing" says what it needs. Run it on a quiet machine.
#
#   zsh plb2/reproduce.zsh                     everything
#   SYSL=/path/to/sysl zsh plb2/reproduce.zsh  with a sysl other than the one on PATH
#   PLB2_SEED=<n> ...                          the timing order of an earlier run

here=${0:A:h}

zsh $here/scripts/build.zsh
print "build: $? (a failed cell is reported, not fatal; build/status.tsv has every cell)"

python3 -I $here/scripts/verify.py
if grep -q $'\tsysl\tWRONG' $here/build/verify.tsv; then
  print "a sysl program printed a wrong answer; not timing"
  exit 1
fi

zsh $here/scripts/time.zsh || exit 1
python3 -I $here/scripts/report.py || exit 1
