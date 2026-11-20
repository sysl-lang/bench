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
            "mandelbrot", "fasta", "knucleotide", "revcomp", "regexredux", "pidigits"]
# Go is the one garbage-collected language (README, methodology item 9).
columns = ["c", "rust", "cpp", "zig", "odin", "c3", "ada", "fortran", "swift",
           "go", "sysl-idiomatic", "sysl-tuned"]
# A run with a second sysl compiler (SYSL_DEV, scripts/lib.zsh) has its two columns too.
sysl_dev = os.environ.get("SYSL_DEV")
if sysl_dev:
    columns += ["sysl-idiomatic-dev", "sysl-tuned-dev"]


def run(cmd):
    env = dict(os.environ)
    env["PATH"] = (os.path.expanduser("~/.local/gnat-16.1.0/bin") + ":/Users/work/.cargo/bin:"
                   + env["PATH"])
    out = subprocess.run(cmd, capture_output=True, text=True, env=env, input="")
    return (out.stdout + out.stderr).strip()


def first_line(text):
    return text.splitlines()[0] if text else ""


clang_version = run(["/usr/bin/clang", "-E", "-dM", "-"]).split("__clang_version__")
clang_llvm = clang_version[1].splitlines()[0].strip().strip('"') if len(clang_version) > 1 else ""

toolchains = {
    "sysl": {"version": first_line(run(["sysl", "--version"])) + " (" + run(["which", "sysl"]) + ")",
             "backend": "emits LLVM IR, which the first clang on PATH (Apple clang, below) optimises and links"},
    **({"sysl-dev": {"version": first_line(run([sysl_dev, "--version"])) + " (" + sysl_dev + ")"
                                + (", " + os.environ["SYSL_DEV_COMMIT"] if os.environ.get("SYSL_DEV_COMMIT") else ""),
                     "backend": "the same clang as sysl"}} if sysl_dev else {}),
    "homebrew-llvm": {"version": first_line(run(["/opt/homebrew/opt/llvm/bin/clang", "--version"]))},
    "c": {"version": first_line(run(["/usr/bin/clang", "--version"])), "llvm": clang_llvm},
    "cpp": {"version": first_line(run(["/usr/bin/clang++", "--version"])), "llvm": clang_llvm},
    "rust": {"version": first_line(run(["rustc", "--version"])),
             "llvm": run(["rustc", "--version", "--verbose"]).split("LLVM version:")[-1].strip()},
    "swift": {"version": first_line(run(["swiftc", "--version"])), "llvm": clang_llvm},
    "zig": {"version": "zig " + first_line(run(["zig", "version"]))},
    "odin": {"version": first_line(run(["odin", "version"])), "llvm": clang_llvm},
    "c3": {"version": first_line(run(["c3c", "--version"])),
           "llvm": run(["c3c", "--version"]).split("LLVM version:")[1].split("\n")[0].strip()},
    "ada": {"version": first_line(run(["gnat", "--version"])),
            "backend": "GCC's own back end (not LLVM)"},
    "fortran": {"version": first_line(run(["gfortran", "--version"])),
                "backend": "GCC's own back end (not LLVM); fortran-stdlib "
                           + run(["pkg-config", "--modversion", "fortran_stdlib"])},
    "go": {"version": first_line(run(["go", "version"])),
           "backend": "Go's own compiler and garbage collector (not LLVM); cgo's C through Apple clang"},
    "hyperfine": {"version": first_line(run(["hyperfine", "--version"]))},
}
flags = {
    "sysl": "sysl build --release -O3 --cpu native (bounds checks stay on; sysl-tuned drops them inside "
            "its `@unchecked` blocks; integer overflow wraps in a release build)",
    "c": "clang -std=gnu17 -pipe -O3 -fomit-frame-pointer -mcpu=native, plus each Game entry's own "
         "-fopenmp (Homebrew libomp), -pthread and libraries (SOURCES.md); -mcpu, because Apple clang "
         "reads -march=native on arm64 as apple-m1",
    "cpp": "clang++ -std=c++20 -O3 -mcpu=native",
    "rust": "cargo build --release: opt-level=3, codegen-units=1, -C target-cpu=native, edition 2015 as the "
            "Game's bare rustc; each Game entry's crates (rayon and others, SOURCES.md); bounds checks "
            "stay on, overflow wraps",
    "swift": "swiftc -O (bounds checks and integer-overflow traps stay on; no CPU option, so generic arm64)",
    "zig": "zig build-exe -O ReleaseFast -mcpu=native -fsingle-threaded",
    "odin": "odin build -o:speed -microarch:native (bounds checks stay on)",
    "c3": "c3c compile -O3 (-O3 is c3c's unsafe mode: runtime bounds checks and contracts are off; "
          "c3c has no native-CPU option for arm64)",
    "ada": "gnatmake -O3 -gnatp -march=native (-gnatp suppresses every run-time check, "
           "bounds checks included, as C's -O3 has none; GNAT is GCC's Ada front end and "
           "uses GCC's back end)",
    "fortran": "gfortran -O3 -march=native (no -ffast-math: IEEE semantics as in C; no bounds "
               "checks, which gfortran adds only under -fcheck=bounds); knucleotide links "
               "fortran-stdlib's hash map",
    "go": "GOARM64=v8.7 go build (no other flag, as the Benchmarks Game builds Go, which sets "
          "GOAMD64=v2; v8.7 is this machine's level; bounds checks stay on); run with GOMAXPROCS=1 and "
          "the default GOGC=100; pidigits calls GMP and regex-redux PCRE2 through cgo",
}
machine = {"cpu": run(["sysctl", "-n", "machdep.cpu.brand_string"]),
           "model": run(["sysctl", "-n", "hw.model"]),
           "performance_cores": run(["sysctl", "-n", "hw.perflevel0.physicalcpu"]),
           "efficiency_cores": run(["sysctl", "-n", "hw.perflevel1.physicalcpu"]),
           "memory_bytes": run(["sysctl", "-n", "hw.memsize"]),
           "os": first_line(run(["sw_vers", "-productVersion"])),
           "os_build": first_line(run(["sw_vers", "-buildVersion"])),
           "power": first_line(run(["pmset", "-g", "ps"]))}

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
        if lang not in rows:  # a DNF cell (scripts/lib.zsh): not timed
            continue
        ms = rows[lang]["measurements"]
        wall = [m["time_wall_clock"]["value"] for m in ms]
        cpu = [m["time_cpu"]["value"] for m in ms]
        mean, stddev, low, median = stats(wall)
        # Every run's own figures are kept, so that any statistic can be recomputed from the file.
        entry[lang] = {"mean": mean, "stddev": stddev, "min": low, "median": median,
                       "cpu_mean": sum(cpu) / len(cpu), "runs": len(wall),
                       "wall_seconds": wall, "cpu_seconds": cpu,
                       "user_seconds": [m["time_user"]["value"] for m in ms],
                       "system_seconds": [m["time_system"]["value"] for m in ms],
                       "peak_rss_bytes": [m.get("memory_peak_resident", {}).get("value") for m in ms],
                       "exit_codes": [m.get("exit_code") for m in ms]}
    base, cpu_base = entry["c"]["mean"], entry["c"]["cpu_mean"]
    for lang in entry:
        entry[lang]["ratio_to_c"] = entry[lang]["mean"] / base
        entry[lang]["cpu_ratio_to_c"] = entry[lang]["cpu_mean"] / cpu_base
    data[prog] = entry

# Every geometric mean is over the programs that every column finished, so that the columns stay
# comparable; a program with a DNF cell is left out of all of them, and the report names it.
dnf = [cell.split(":") for cell in os.environ.get("BENCH_DNF", "").split(",") if cell]
dnf = [(p, l) for p, l in dnf if p in programs and l in columns]
common = [p for p in programs if all(lang in data[p] for lang in columns)]

geo = {}
cpu_geo = {}
for lang in columns:
    vals = [data[p][lang]["ratio_to_c"] for p in common]
    geo[lang] = math.exp(sum(math.log(v) for v in vals) / len(vals))
    vals = [data[p][lang]["cpu_ratio_to_c"] for p in common]
    cpu_geo[lang] = math.exp(sum(math.log(v) for v in vals) / len(vals))

def group_geo(langs, key):
    vals = [data[p][lang][key] for p in common for lang in langs]
    return math.exp(sum(math.log(v) for v in vals) / len(vals))


def cell(e, lang, key, fmt):
    return format(e[lang][key], fmt) if lang in e else "DNF"


overall_geo = {"wall": group_geo(columns, "ratio_to_c"), "cpu": group_geo(columns, "cpu_ratio_to_c")}

# The comparison a headline about speed may quote (AUDIT.md A6): each language's FASTER column (sysl
# has two, idiomatic and tuned) against C on that program. C and Rust are each the Game's fastest entry
# that builds unmodified here, so they have one column each (AUDIT.md, D-TUNED superseded).
best_columns = {"sysl": ["sysl-idiomatic", "sysl-tuned"],
                **{lang: [lang] for lang in ["c", "rust", "cpp", "zig", "odin", "c3", "ada", "fortran", "swift", "go"]}}
best = {}
for prog in common:
    e = data[prog]
    c_best = min(e[c]["mean"] for c in best_columns["c"] if c in e)
    best[prog] = {lang: min(e[c]["mean"] for c in cols if c in e) / c_best
                  for lang, cols in best_columns.items() if any(c in e for c in cols)}
best_geo = {lang: math.exp(sum(math.log(best[p][lang]) for p in common) / len(common))
            for lang in best_columns}

doc = {"date": stamp, "columns": columns,
       "best_column_ratio_to_best_c": best, "best_column_geometric_mean": best_geo,
       "best_columns": best_columns,
       "overall_geometric_mean_ratio_to_c": overall_geo, "machine": machine, "toolchains": toolchains, "flags": flags,
       "hyperfine": "--warmup 3 --runs 10",
       "load": {"start": load("load-start.txt"), "end": load("load-end.txt")}, "programs": data, "geometric_mean_ratio_to_c": geo,
       "geometric_mean_cpu_ratio_to_c": cpu_geo, "geometric_mean_programs": common,
       "dnf": [{"program": p, "language": l} for p, l in dnf]}
with open(os.path.join(root, "results", stamp + ".json"), "w") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")

lines = [f"# Results {stamp}", "",
         f"{machine['cpu']} ({machine['model']}; {machine['performance_cores']} performance and "
         f"{machine['efficiency_cores']} efficiency cores; {int(machine['memory_bytes']) // 2**30} GiB), "
         f"macOS {machine['os']} ({machine['os_build']}), {machine['power']}. Single-threaded, "
         "`hyperfine -N --warmup 3 --runs 10`; each program's languages run one after another in a fixed "
         "order, every run of one language before the next. Every run's own times are in the JSON file "
         "beside this one.", "",
         *([f"**{os.environ['BENCH_NOTE']}**", ""] if os.environ.get("BENCH_NOTE") else []),
         "Each cell is the mean time as a ratio to C (1.00 = as fast as C, higher is slower). "
         "The `C (s)` column is C's own mean in seconds. Go is the one language here with a garbage "
         "collector, run with `GOMAXPROCS=1` (README, methodology item 9).", "",
         "Load average at the start and end of the run (`uptime`); if other builds were running, "
         "the figures were measured under load and are noisier than an idle-machine run:", "",
         "```", doc["load"]["start"], doc["load"]["end"], "```", "",
         "| program | C (s) | " + " | ".join(c for c in columns if c != "c") + " |",
         "|---|---:|" + "---:|" * (len(columns) - 1)]
for prog in programs:
    e = data[prog]
    cells = " | ".join(cell(e, c, "ratio_to_c", ".2f") for c in columns if c != "c")
    lines.append(f"| {prog} | {e['c']['mean']:.3f} | {cells} |")
lines.append("| **geometric mean** | | " +
             " | ".join(f"{geo[c]:.2f}" for c in columns if c != "c") + " |")
if dnf:
    lines += ["", "**DNF** (did not finish) cells were verified at the small size and not timed: " +
              "; ".join(f"{p}/{l}" for p, l in dnf) + ". Every geometric mean is over the programs every "
              f"column finished ({', '.join(common)}), so the columns stay comparable."]
lines += ["", f"Geometric mean over every program and language, C included (wall clock): "
          f"**{overall_geo['wall']:.2f}**."]
best_langs = list(best_columns)
lines += ["", "## Each language at its best", "",
          "The comparison to quote. Each cell is the language's faster column on that program as a ratio "
          "to `c`, by wall-clock mean. Only sysl has two columns (idiomatic and tuned); C and Rust are each "
          "the Benchmarks Game's fastest entry that builds unmodified here, and every other language is "
          "its one program.",
          "",
          "| program | " + " | ".join(best_langs) + " |",
          "|---|" + "---:|" * len(best_langs)]
for prog in common:
    lines.append(f"| {prog} | " + " | ".join(f"{best[prog][l]:.2f}" for l in best_langs) + " |")
lines.append("| **geometric mean** | " + " | ".join(f"{best_geo[l]:.2f}" for l in best_langs) + " |")
lines += ["", "## CPU time", "",
          "The same ratios computed from CPU time (user plus system) instead of wall-clock time, which a "
          "busy machine disturbs less.", "",
          "| program | C (s) | " + " | ".join(c for c in columns if c != "c") + " |",
          "|---|---:|" + "---:|" * (len(columns) - 1)]
for prog in programs:
    e = data[prog]
    cells = " | ".join(cell(e, c, "cpu_ratio_to_c", ".2f") for c in columns if c != "c")
    lines.append(f"| {prog} | {e['c']['cpu_mean']:.3f} | {cells} |")
lines.append("| **geometric mean** | | " +
             " | ".join(f"{cpu_geo[c]:.2f}" for c in columns if c != "c") + " |")
lines += ["", f"Geometric mean over every program and language, C included (CPU): "
          f"**{overall_geo['cpu']:.2f}**."]
lines += ["", "## Spread", "",
          "Each cell is the standard deviation of the wall-clock runs as a percentage of their mean "
          f"({data[programs[0]]['c']['runs']} runs each): the noise a difference between two cells has to beat.", "",
          "| program | " + " | ".join(columns) + " |",
          "|---|" + "---:|" * len(columns)]
for prog in programs:
    e = data[prog]
    cells = " | ".join(f"{100 * e[c]['stddev'] / e[c]['mean']:.1f}" if c in e else "DNF" for c in columns)
    lines.append(f"| {prog} | {cells} |")
if sysl_dev:
    lines += ["", "## sysl compilers", "",
              f"The same sysl sources built by `sysl` ({toolchains['sysl']['version']}) and by `sysl-dev` "
              f"({toolchains['sysl-dev']['version']}). Times are means in seconds ± one standard deviation; "
              "`change` is dev's mean against the base's (negative is faster).", "",
              "| program | idiomatic base (s) | idiomatic dev (s) | change | tuned base (s) | tuned dev (s) | change |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for prog in programs:
        e = data[prog]
        cells = []
        for col in ["sysl-idiomatic", "sysl-tuned"]:
            b, d = e.get(col), e.get(col + "-dev")
            cells += [f"{b['mean']:.3f} ± {b['stddev']:.3f}" if b else "DNF",
                      f"{d['mean']:.3f} ± {d['stddev']:.3f}" if d else "DNF",
                      f"{100 * (d['mean'] / b['mean'] - 1):+.1f}%" if b and d else "—"]
        lines.append(f"| {prog} | " + " | ".join(cells) + " |")
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
