#!/bin/zsh
# Times every built program with hyperfine, as upstream's README does: wall-clock time of the whole
# process, default problem sizes, no arguments, `-N` (no shell) and one warm-up run. The (program,
# language) pairs run in an order shuffled from a recorded seed, so a drift in the machine's state
# does not always land on the same language. PLB2_SEED replays an order.
#
# Writes results/raw/<program>-<language>.json (hyperfine's own JSON, wall, user and system time of
# every run) and results/meta.json (seed, order, machine, toolchains, flags), and copies the build
# and verification tables into results/.
#
# SYSL_LABEL names the sysl compiler in meta.json where its --version does not (a dev build).
# PLB2_RESULTS and PLB2_RUNS (a fixed run count) are for a smoke test of the scripts only; a
# published result uses neither.

source ${0:A:h}/lib.zsh
source ${0:A:h}/flags.zsh
cd $PLB2

seed=${PLB2_SEED:-$(date +%s)}
results=${PLB2_RESULTS:-$PLB2/results}
runs=()
[[ -n $PLB2_RUNS ]] && runs=(--runs $PLB2_RUNS)
raw=$results/raw
rm -rf $raw
mkdir -p $raw
cp $BUILD/status.tsv $BUILD/verify.tsv $results/

cells=()
for line in ${(f)"$(tail -n +2 $BUILD/status.tsv)"}; do
  fields=(${(ps:\t:)line})
  [[ $fields[3] == built ]] && cells+=($fields[1]/$fields[2])
done
order=($(python3 -I -c 'import random, sys
c = sys.argv[2:]
random.Random(int(sys.argv[1])).shuffle(c)
print(*c)' $seed $cells))

print "seed $seed; ${#order} programs"
for cell in $order; do
  prog=${cell%/*}
  lang=${cell#*/}
  hyperfine -N --warmup 1 $runs --style basic --command-name $cell \
    --export-json $raw/$prog-$lang.json $(exe $prog $lang) || exit 1
done

version() { print -r -- "${$("$@" 2>&1)[(f)1]}"; }
typeset -A tool
tool=(
  c      "$(version cc --version)"
  rust   "$(version rustc --version)"
  zig    "$(version zig version)"
  swift  "$(version swiftc --version)"
  nim    "$(version nim --version)"
  d      "$(version ldc2 --version)"
  sysl   "${SYSL_LABEL:-$(version $SYSL --version) ($(whence -p $SYSL || print $SYSL))}"
)

python3 -I - $results/meta.json $seed "$(sw_vers -productVersion 2>/dev/null || uname -sr)" \
  "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)" "$(sysctl -n hw.model 2>/dev/null)" \
  "$(hyperfine --version)" "${(j: :)order}" \
  ${(kv)tool} -- ${(kv)FLAGS} <<'EOF'
import datetime, json, sys
out, seed, os_, cpu, model, hf, order, *rest = sys.argv[1:]
split = rest.index("--")
tools, flags = rest[:split], rest[split + 1:]
json.dump({
    "date": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "seed": int(seed), "order": order.split(), "os": os_, "cpu": cpu, "model": model,
    "hyperfine": hf,
    "toolchains": dict(zip(tools[::2], tools[1::2])),
    "flags": dict(zip(flags[::2], flags[1::2])),
}, open(out, "w"), indent=2)
EOF
print "wrote $raw and $results/meta.json"
