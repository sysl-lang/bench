#!/bin/zsh
# Reproduces the AWFY track from nothing: checks the toolchain, fetches upstream at the pinned
# commit and checks every upstream file kept here against it, builds both ports, runs every
# benchmark's own verification, times the suite, and writes the raw JSON and the reports.
#
#   zsh reproduce.zsh                     the full run: 30 invocations x 10 iterations (METHODOLOGY.md)
#   zsh reproduce.zsh --smoke             one invocation of one iteration, into build/smoke: proves
#                                         the pipeline end to end; its numbers are not a result
#   zsh reproduce.zsh --invocations N --iterations N --out DIR
#   zsh reproduce.zsh --langs sysl,cpp,zig,rust   the languages run (default sysl,cpp; METHODOLOGY.md § 2)
#
# Writes <out>/<stamp>.json (every iteration, the machine, versions, flags), <out>/<stamp>.md and
# <out>/report.html. <out> is results/ by default. Needs sysl 0.12.0 or later, clang, python3, git.

AWFY_ROOT=${0:A:h}
out=$AWFY_ROOT/results
smoke=0
while (( $# )); do
  case $1 in
    --smoke) smoke=1; out=$AWFY_ROOT/build/smoke ;;
    --invocations) export INVOCATIONS=$2; shift ;;
    --iterations) export ITERATIONS=$2; shift ;;
    --out) out=${2:A}; shift ;;
    --langs) LANGS=(${(s:,:)2}); shift ;;
    *) sed -n '2,14p' $0; exit 2 ;;
  esac
  shift
done
if (( smoke )); then export INVOCATIONS=1 ITERATIONS=1; fi

# Keep the machine awake for the whole run: a sleep stops every process mid-iteration.
if [[ $OSTYPE == darwin* && -z $AWFY_AWAKE ]] && command -v caffeinate >/dev/null; then
  AWFY_AWAKE=1 exec caffeinate -dimsu zsh $0 "${(@)argv}" $( (( smoke )) && print -- --smoke) \
    --invocations ${INVOCATIONS:-30} --iterations ${ITERATIONS:-10} --out $out \
    $( (( ${+LANGS} )) && print -- --langs ${(j:,:)LANGS})
fi

source $AWFY_ROOT/scripts/config.zsh
setopt err_exit pipe_fail
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
stamp=$(date -u +%Y-%m-%dT%H%MZ)

print "== AWFY: ${(j:, :)LANGS}, $INVOCATIONS invocations x $ITERATIONS iterations"
LANGS="$LANGS" zsh $AWFY_ROOT/scripts/setup.zsh

print "== machine"
print "load: $(uptime)"
if [[ $OSTYPE == darwin* ]]; then
  print "model: $(sysctl -n hw.model), $(sysctl -n machdep.cpu.brand_string)"
  pmset -g batt | head -1
  [[ $(pmset -g batt | head -1) == *"AC Power"* ]] || print "WARNING: not on AC power; METHODOLOGY.md asks for it"
  [[ $(pmset -g | awk '$1 == "sleep" {print $2}') == 0 ]] || print "WARNING: system sleep is not 0 (caffeinate holds it off)"
fi

print "== build"
LANGS="$LANGS" zsh $AWFY_ROOT/scripts/build.zsh

print "== verify (each benchmark once, at its timed size, checked by the harness)"
LANGS="$LANGS" zsh $AWFY_ROOT/scripts/verify.zsh

print "== time"
raw=$BUILD/raw-$stamp
rm -rf $raw
LANGS="$LANGS" zsh $AWFY_ROOT/scripts/run.zsh $raw
finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)

print "== report"
mkdir -p $out
pairs=()
for bench in $BENCHMARKS; do pairs+=("\"$bench\":$INNER[$bench]"); done
inner_json="{${(j:,:)pairs}}"
python3 -I $AWFY_ROOT/scripts/report.py collect $raw $BUILD $out/$stamp.json \
  upstream_url=$UPSTREAM_URL upstream_commit=$UPSTREAM_COMMIT started=$started finished=$finished \
  invocations=$INVOCATIONS iterations=$ITERATIONS inner=$inner_json langs="$LANGS" \
  sysl=$SYSL clang=$CLANG \
  sysl_binary_bytes=$(stat -f %z $(harness_of sysl) 2>/dev/null || stat -c %s $(harness_of sysl)) \
  cpp_binary_bytes=$(stat -f %z ${$(harness_of cpp):A} 2>/dev/null || stat -c %s ${$(harness_of cpp):A}) \
  $( (( ${LANGS[(Ie)zig]} )) && print -- zig_version=$($ZIG version) zig_binary_bytes=$(stat -f %z $(harness_of zig) 2>/dev/null || stat -c %s $(harness_of zig))) \
  $( (( ${LANGS[(Ie)rust]} )) && print -- rust_version=${${(z)$(${CARGO:h}/rustc --version)}[2]} rust_binary_bytes=$(stat -f %z $(harness_of rust) 2>/dev/null || stat -c %s $(harness_of rust)))
python3 -I $AWFY_ROOT/scripts/report.py render $out/$stamp.json $out/$stamp.md $out/report.html
rm -rf $raw
print "wrote $out/$stamp.json, $out/$stamp.md, $out/report.html"
