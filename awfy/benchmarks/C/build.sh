#!/bin/bash
# Builds the C port's harness from every source in one clang invocation, so -flto optimises the
# whole program together as it does the C++ port. The knobs are upstream C++ build.sh's: CC (the
# compiler) and OPT (the optimisation flags); -ffp-contract=off is added as build.sh adds it for C++.
#
#   CC=clang OPT='-O3 -flto -mcpu=native' bash build.sh <output binary>
set -e
cd "$(dirname "$0")"
CC=${CC:-clang}
OPT=${OPT:-'-O3 -flto -mcpu=native'}
OUT=${1:-harness}
SRC=(src/*.c src/memory/*.c)
# shellcheck disable=SC2086
"$CC" $OPT -ffp-contract=off -std=c17 -Wall -Wextra -Werror -o "$OUT" "${SRC[@]}" -lm
