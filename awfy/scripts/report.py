"""Turns the raw harness output of `run.zsh time` into results/<date>.json and results/<date>.md.

    python3 -I scripts/report.py <raw dir> <date> [<lang> <warm-up iterations> ...]

Each raw file `<lang>-<Benchmark>-<n>.out` is one invocation of a harness; its lines
`<Benchmark>: iterations=1 runtime: <us>us` are the per-iteration times. The first <warm-up>
iterations of every invocation are dropped, and the rest of all invocations are pooled. The
matching `.time` file is the stderr of `/usr/bin/time -l`, which gives the peak resident set size.
"""

import json
import math
import os
import re
import statistics
import sys

LANGS = ["sysl", "cpp", "java"]
BASELINE = "cpp"
BENCHMARKS = ["DeltaBlue", "Richards", "Json", "CD", "Havlak", "Bounce", "List", "Mandelbrot", "NBody",
              "Permute", "Queens", "Sieve", "Storage", "Towers"]
RUNTIME = re.compile(r": iterations=1 runtime: (\d+)us")
PEAK_RSS = re.compile(r"(\d+)\s+maximum resident set size")


def read(path):
    with open(path) as f:
        return f.read()


def read_number(path):
    return float(read(path).strip()) if os.path.exists(path) else None


def main():
    raw, stamp = sys.argv[1], sys.argv[2]
    pairs = sys.argv[3:]
    warmup = {pairs[i]: int(pairs[i + 1]) for i in range(0, len(pairs), 2)}
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    results = {}
    for bench in BENCHMARKS:
        results[bench] = {}
        for lang in LANGS:
            times, rss = [], []
            n = 1
            while os.path.exists(os.path.join(raw, f"{lang}-{bench}-{n}.out")):
                runs = [int(m) for m in RUNTIME.findall(read(os.path.join(raw, f"{lang}-{bench}-{n}.out")))]
                times += runs[warmup.get(lang, 0):]
                m = PEAK_RSS.search(read(os.path.join(raw, f"{lang}-{bench}-{n}.time")))
                if m:
                    rss.append(int(m.group(1)))
                n += 1
            if times:
                results[bench][lang] = {
                    "iterations_us": times,
                    "mean_us": statistics.mean(times),
                    "stddev_us": statistics.stdev(times) if len(times) > 1 else 0.0,
                    "peak_rss_bytes": max(rss) if rss else None,
                }

    meta = {
        "date": stamp,
        "load_start": read(os.path.join(raw, "load-start.txt")).strip(),
        "load_end": read(os.path.join(raw, "load-end.txt")).strip(),
        "warmup_iterations": warmup,
        "build_seconds": {lang: read_number(os.path.join(raw, f"{lang}.build-seconds")) for lang in LANGS},
        "binary_bytes": {lang: read_number(os.path.join(raw, f"{lang}.binary-bytes")) for lang in ["sysl", "cpp"]},
        "java_classes_kbytes": read_number(os.path.join(raw, "java.classes-kbytes")),
    }

    os.makedirs(os.path.join(root, "results"), exist_ok=True)
    with open(os.path.join(root, "results", f"{stamp}.json"), "w") as f:
        json.dump({"meta": meta, "results": results}, f, indent=1)
        f.write("\n")

    lines = [f"# Are We Fast Yet — {stamp}", "",
             "Mean time per iteration (ms) ± standard deviation, and the ratio to C++ (lower is faster).", "",
             "| benchmark | " + " | ".join(LANGS) + " | " + " | ".join(f"{l}/cpp" for l in LANGS if l != BASELINE) + " |",
             "|---|" + "---:|" * (2 * len(LANGS) - 1)]
    ratios = {l: [] for l in LANGS if l != BASELINE}
    for bench in BENCHMARKS:
        r = results[bench]
        cells = [f"{r[l]['mean_us'] / 1000:.2f} ± {r[l]['stddev_us'] / 1000:.2f}" if l in r else "—" for l in LANGS]
        rcells = []
        for l in ratios:
            if l in r and BASELINE in r:
                q = r[l]["mean_us"] / r[BASELINE]["mean_us"]
                ratios[l].append(q)
                rcells.append(f"{q:.2f}")
            else:
                rcells.append("—")
        lines.append(f"| {bench} | " + " | ".join(cells) + " | " + " | ".join(rcells) + " |")
    geo = [f"{math.exp(sum(map(math.log, q)) / len(q)):.2f}" if q else "—" for q in ratios.values()]
    lines.append("| **geomean** | " + " | ".join("" for _ in LANGS) + " | " + " | ".join(geo) + " |")
    lines += ["", "Each geometric mean is over the benchmarks that language ran: " +
              ", ".join(f"{l} {len(q)}" for l, q in ratios.items()) + "."]

    lines += ["", "Peak resident set size (MB), the largest of the invocations.", "",
              "| benchmark | " + " | ".join(LANGS) + " |", "|---|" + "---:|" * len(LANGS)]
    for bench in BENCHMARKS:
        r = results[bench]
        lines.append(f"| {bench} | " + " | ".join(
            f"{r[l]['peak_rss_bytes'] / 1e6:.1f}" if l in r and r[l]["peak_rss_bytes"] else "—" for l in LANGS) + " |")

    bs, bb = meta["build_seconds"], meta["binary_bytes"]
    lines += ["", "| | sysl | cpp | java |", "|---|---:|---:|---:|",
              "| build time (s) | " + " | ".join(f"{bs[l]:.1f}" if bs[l] else "—" for l in LANGS) + " |",
              f"| harness size (KB) | {bb['sysl'] / 1024:.0f} | {bb['cpp'] / 1024:.0f} | "
              f"{meta['java_classes_kbytes']:.0f} (classes) |",
              "", f"Load at start: `{meta['load_start']}`", "", f"Load at end: `{meta['load_end']}`", ""]

    with open(os.path.join(root, "results", f"{stamp}.md"), "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))


main()
