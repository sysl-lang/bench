"""Turns hyperfine's per-program JSON into results/<date>.json and results/<date>.md.

usage: report.py <raw dir> <date>
"""
import json
import math
import os
import subprocess
import sys

raw, stamp = sys.argv[1], sys.argv[2]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

programs = ["nbody", "spectralnorm", "fannkuchredux", "binarytrees",
            "mandelbrot", "fasta", "knucleotide", "revcomp"]
systems = ["c", "rust", "cpp", "zig", "d", "odin", "c3", "nim", "swift", "sysl-idiomatic", "sysl-fast"]
managed = ["go", "java", "eiffel", "eiffel-contracts", "julia"]
columns = systems + managed


def run(cmd):
    env = dict(os.environ)
    env["PATH"] = "/Users/work/.cargo/bin:" + env["PATH"]
    out = subprocess.run(cmd, capture_output=True, text=True, env=env, input="")
    return (out.stdout + out.stderr).strip()


def first_line(text):
    return text.splitlines()[0] if text else ""


clang_version = run(["/usr/bin/clang", "-E", "-dM", "-"]).split("__clang_version__")
clang_llvm = clang_version[1].splitlines()[0].strip().strip('"') if len(clang_version) > 1 else ""

toolchains = {
    "sysl": {"version": first_line(run(["sysl", "--version"])),
             "backend": "emits LLVM IR, which Apple clang (below) optimises and links"},
    "c": {"version": first_line(run(["/usr/bin/clang", "--version"])), "llvm": clang_llvm},
    "cpp": {"version": first_line(run(["/usr/bin/clang++", "--version"])), "llvm": clang_llvm},
    "rust": {"version": first_line(run(["rustc", "--version"])),
             "llvm": run(["rustc", "--version", "--verbose"]).split("LLVM version:")[-1].strip()},
    "swift": {"version": first_line(run(["swiftc", "--version"])), "llvm": clang_llvm},
    "zig": {"version": "zig " + first_line(run(["zig", "version"]))},
    "nim": {"version": first_line(run(["nim", "--version"])), "llvm": clang_llvm},
    "julia": {"version": first_line(run(["julia", "--version"]))},
    "go": {"version": first_line(run(["go", "version"]))},
    "d": {"version": first_line(run(["ldc2", "--version"])),
          "llvm": run(["ldc2", "--version"]).split("LLVM ")[1].split("\n")[0].strip()},
    "odin": {"version": first_line(run(["odin", "version"])), "llvm": clang_llvm},
    "c3": {"version": first_line(run(["c3c", "--version"])),
           "llvm": run(["c3c", "--version"]).split("LLVM version:")[1].split("\n")[0].strip()},
    "java": {"version": first_line(run(["java", "--version"]))},
    "eiffel": {"version": first_line(run(["ec", "-version"])), "llvm": clang_llvm},
    "hyperfine": {"version": first_line(run(["hyperfine", "--version"]))},
}
flags = {
    "sysl": "sysl build --release -O3 --cpu native",
    "c": "clang -std=gnu17 -O3 -march=native",
    "cpp": "clang++ -std=c++20 -O3 -march=native",
    "rust": "rustc --edition 2021 -C opt-level=3 -C target-cpu=native",
    "swift": "swiftc -O",
    "zig": "zig build-exe -O ReleaseFast -mcpu=native -fsingle-threaded",
    "nim": "nim c -d:danger --opt:speed --mm:orc --cc:clang --passC:-march=native --threads:off",
    "go": "go build (default flags: Go has no optimisation level; bounds checks stay on)",
    "d": "ldc2 -O3 -release -mcpu=native (-release drops asserts and the bounds checks of @system code)",
    "odin": "odin build -o:speed -microarch:native (bounds checks stay on)",
    "c3": "c3c compile -O3 (-O3 is c3c's unsafe mode: runtime bounds checks and contracts are off; "
          "c3c has no native-CPU option for arm64)",
    "java": "javac, then java -cp (default JIT flags; bounds checks stay on; JVM startup and JIT "
            "warm-up are inside every timed run, as on the Benchmarks Game)",
    "eiffel": "ec -finalize -c_compile, ECF target `release`: every assertion off (precondition, "
              "postcondition, check, invariant, loop); the C compiler is the machine's clang with "
              "EiffelStudio's own flags, which have no native-CPU option; array indices are not "
              "range-checked, as they are by a precondition",
    "eiffel-contracts": "the same source as `eiffel`, ECF target `contracts`: precondition, "
                        "postcondition, check, invariant and loop (invariant and variant) "
                        "assertions all on",
    "julia": "julia -O3 --check-bounds=no --startup-file=no (JIT: every timed run includes "
             "Julia's startup and compilation, as on the Benchmarks Game)",
}
machine = {"cpu": run(["sysctl", "-n", "machdep.cpu.brand_string"]),
           "os": first_line(run(["sw_vers", "-productVersion"]))}

def load(name):
    with open(os.path.join(raw, name)) as f:
        return f.read().strip()


def stats(values):
    n = len(values)
    mean = sum(values) / n
    var = sum((v - mean) ** 2 for v in values) / (n - 1) if n > 1 else 0.0
    ordered = sorted(values)
    median = ordered[n // 2] if n % 2 else (ordered[n // 2 - 1] + ordered[n // 2]) / 2
    return mean, math.sqrt(var), ordered[0], median


data = {}
for prog in programs:
    with open(os.path.join(raw, prog + ".json")) as f:
        rows = {r["name"]: r for r in json.load(f)["results"]}
    entry = {}
    for lang in columns:
        ms = rows[lang]["measurements"]
        wall = [m["time_wall_clock"]["value"] for m in ms]
        cpu = [m["time_cpu"]["value"] for m in ms]
        mean, stddev, low, median = stats(wall)
        entry[lang] = {"mean": mean, "stddev": stddev, "min": low, "median": median,
                       "cpu_mean": sum(cpu) / len(cpu), "runs": len(wall)}
    base, cpu_base = entry["c"]["mean"], entry["c"]["cpu_mean"]
    for lang in columns:
        entry[lang]["ratio_to_c"] = entry[lang]["mean"] / base
        entry[lang]["cpu_ratio_to_c"] = entry[lang]["cpu_mean"] / cpu_base
    data[prog] = entry

geo = {}
cpu_geo = {}
for lang in columns:
    vals = [data[p][lang]["ratio_to_c"] for p in programs]
    geo[lang] = math.exp(sum(math.log(v) for v in vals) / len(vals))
    vals = [data[p][lang]["cpu_ratio_to_c"] for p in programs]
    cpu_geo[lang] = math.exp(sum(math.log(v) for v in vals) / len(vals))

def group_geo(langs, key):
    vals = [data[p][lang][key] for p in programs for lang in langs]
    return math.exp(sum(math.log(v) for v in vals) / len(vals))


group_geo_wall = {"all": group_geo(columns, "ratio_to_c"), "systems": group_geo(systems, "ratio_to_c"),
                  "managed": group_geo(managed, "ratio_to_c")}
group_geo_cpu = {"all": group_geo(columns, "cpu_ratio_to_c"), "systems": group_geo(systems, "cpu_ratio_to_c"),
                 "managed": group_geo(managed, "cpu_ratio_to_c")}

doc = {"date": stamp, "groups": {"systems": systems, "managed": managed},
       "group_geometric_mean_ratio_to_c": group_geo_wall,
       "group_geometric_mean_cpu_ratio_to_c": group_geo_cpu, "machine": machine, "toolchains": toolchains, "flags": flags,
       "hyperfine": "--warmup 3 --runs 10",
       "load": {"start": load("load-start.txt"), "end": load("load-end.txt")}, "programs": data, "geometric_mean_ratio_to_c": geo,
       "geometric_mean_cpu_ratio_to_c": cpu_geo}
with open(os.path.join(root, "results", stamp + ".json"), "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")

lines = [f"# Results {stamp}", "",
         f"{machine['cpu']}, macOS {machine['os']}. Single-threaded, `hyperfine --warmup 3 --runs 10`.", "",
         *([f"**{os.environ['BENCH_NOTE']}**", ""] if os.environ.get("BENCH_NOTE") else []),
         "Each cell is the mean time as a ratio to C (1.00 = as fast as C, higher is slower). "
         "The `C (s)` column is C's own mean in seconds. Columns are grouped: **systems** languages "
         f"({', '.join(systems)}) first, then **managed** ({', '.join(managed)}).", "",
         "Load average at the start and end of the run (`uptime`); if other builds were running, "
         "the figures were measured under load and are noisier than an idle-machine run:", "",
         "```", doc["load"]["start"], doc["load"]["end"], "```", "",
         "| program | C (s) | " + " | ".join(c for c in columns if c != "c") + " |",
         "|---|---:|" + "---:|" * (len(columns) - 1)]
for prog in programs:
    e = data[prog]
    cells = " | ".join(f"{e[c]['ratio_to_c']:.2f}" for c in columns if c != "c")
    lines.append(f"| {prog} | {e['c']['mean']:.3f} | {cells} |")
lines.append("| **geometric mean** | | " +
             " | ".join(f"{geo[c]:.2f}" for c in columns if c != "c") + " |")
lines += ["", "Geometric mean over every program and language in a group (wall clock; systems includes C):", "",
          "| overall | systems | managed |", "|---:|---:|---:|",
          f"| {group_geo_wall['all']:.2f} | {group_geo_wall['systems']:.2f} | {group_geo_wall['managed']:.2f} |"]
lines += ["", "## CPU time", "",
          "The same ratios computed from CPU time (user plus system) instead of wall-clock time, which a "
          "busy machine disturbs less.", "",
          "| program | C (s) | " + " | ".join(c for c in columns if c != "c") + " |",
          "|---|---:|" + "---:|" * (len(columns) - 1)]
for prog in programs:
    e = data[prog]
    cells = " | ".join(f"{e[c]['cpu_ratio_to_c']:.2f}" for c in columns if c != "c")
    lines.append(f"| {prog} | {e['c']['cpu_mean']:.3f} | {cells} |")
lines.append("| **geometric mean** | | " +
             " | ".join(f"{cpu_geo[c]:.2f}" for c in columns if c != "c") + " |")
lines += ["", "| overall (CPU) | systems (CPU) | managed (CPU) |", "|---:|---:|---:|",
          f"| {group_geo_cpu['all']:.2f} | {group_geo_cpu['systems']:.2f} | {group_geo_cpu['managed']:.2f} |"]
lines += ["", "## Toolchains", ""]
for name, t in toolchains.items():
    extra = f" (LLVM: {t['llvm']})" if t.get("llvm") else ""
    lines.append(f"- **{name}**: {t['version']}{extra}")
lines += ["", "## Flags", ""]
for name, fl in flags.items():
    lines.append(f"- **{name}**: `{fl}`")
lines.append("")
with open(os.path.join(root, "results", stamp + ".md"), "w") as f:
    f.write("\n".join(lines))
print("wrote results/%s.json and results/%s.md" % (stamp, stamp))
