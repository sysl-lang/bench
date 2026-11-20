"""The AWFY track's results: collects a timing run into raw JSON, and renders that JSON as Markdown
and as a self-contained HTML page. Standard library only.

    python3 -I report.py collect <raw dir> <build dir> <out.json> <key=value>...
    python3 -I report.py render  <in.json> <out.md> <out.html>

collect reads run.zsh's files: `<invocation>-<lang>-<Benchmark>.out` holds upstream's harness lines
`<Benchmark>: iterations=1 runtime: <us>us`, one per iteration; `.time` is `/usr/bin/time -l`'s
stderr, for the peak resident set size. The JSON keeps every iteration of every invocation, with the
machine, the OS, the toolchain versions, the flags and the build times. Nothing is dropped.

render computes everything from that JSON (METHODOLOGY.md, "The statistic"):
  - per benchmark and language: the mean of every iteration of every invocation, and its sd;
  - the ratio sysl / C++ of those means, with a 95% bootstrap interval;
  - the geometric mean of the fourteen ratios, with a 95% bootstrap interval;
  - the same geometric mean without each invocation's first iteration (a sensitivity check).
The bootstrap resamples whole invocations (each process's iterations stay together), separately per
benchmark and language, 10,000 times, with a fixed seed so the report is reproducible from the JSON.
"""

import html
import json
import math
import os
import platform
import random
import re
import statistics
import subprocess
import sys

BASELINE = "cpp"
SUBJECT = "sysl"
LANG_NAMES = {"sysl": "sysl", "cpp": "C++"}
RUNTIME = re.compile(r"^(\w+): iterations=1 runtime: (\d+)us$", re.M)
PEAK_RSS = re.compile(r"(\d+)\s+maximum resident set size")
BOOTSTRAP = 10_000
SEED = 20161101


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def machine():
    m = {"os": platform.system(), "os_release": platform.release(), "arch": platform.machine()}
    if platform.system() == "Darwin":
        m.update({
            "model": sh("sysctl", "-n", "hw.model"),
            "cpu": sh("sysctl", "-n", "machdep.cpu.brand_string"),
            "cores": sh("sysctl", "-n", "hw.ncpu"),
            "performance_cores": sh("sysctl", "-n", "hw.perflevel0.physicalcpu"),
            "efficiency_cores": sh("sysctl", "-n", "hw.perflevel1.physicalcpu"),
            "memory_bytes": sh("sysctl", "-n", "hw.memsize"),
            "macos": sh("sw_vers", "-productVersion") + " (" + sh("sw_vers", "-buildVersion") + ")",
            "power": sh("pmset", "-g", "batt").splitlines()[0:1],
            "sleep_setting": [" ".join(l.split()[:2]) for l in sh("pmset", "-g").splitlines() if l.strip().startswith("sleep ")],
            "low_power_mode": [" ".join(l.split()) for l in sh("pmset", "-g").splitlines() if "lowpowermode" in l],
        })
    else:
        cpu = [l.split(":", 1)[1].strip() for l in read("/proc/cpuinfo").splitlines() if l.startswith("model name")]
        m.update({"cpu": cpu[0] if cpu else platform.processor(), "cores": str(os.cpu_count()),
                  "memory": next((l for l in read("/proc/meminfo").splitlines() if l.startswith("MemTotal")), "")})
    return m


def collect(raw, build, out, pairs):
    meta = dict(p.split("=", 1) for p in pairs)
    order = [l.split() for l in read(os.path.join(raw, "order.txt")).splitlines() if l.strip()]
    runs = {}
    for inv, lang, bench in order:
        text = read(os.path.join(raw, f"{inv}-{lang}-{bench}.out"))
        times = [int(us) for name, us in RUNTIME.findall(text) if name == bench]
        rss = PEAK_RSS.search(read(os.path.join(raw, f"{inv}-{lang}-{bench}.time")))
        runs.setdefault(bench, {}).setdefault(lang, []).append({
            "invocation": int(inv), "iterations_us": times,
            "peak_rss_bytes": int(rss.group(1)) if rss else None})
    langs = meta.get("langs", "sysl cpp").split()
    toolchain = {
        "sysl": sh(meta.get("sysl", "sysl"), "--version"),
        "clang": sh(meta.get("clang", "clang"), "--version").splitlines()[0:1],
        "python": platform.python_version(),
    }
    builds = {lang: {
        "command": read(os.path.join(build, f"{lang}.command")).strip(),
        "seconds": float(read(os.path.join(build, f"{lang}.build-seconds")) or "nan"),
        "binary_bytes": int(meta[f"{lang}_binary_bytes"]) if meta.get(f"{lang}_binary_bytes") else None,
    } for lang in langs}
    doc = {
        "suite": "Are We Fast Yet (Marr, Daloze, Mössenböck, DLS 2016)",
        "upstream": {"url": meta.get("upstream_url"), "commit": meta.get("upstream_commit")},
        "started": meta.get("started"), "finished": meta.get("finished"),
        "invocations": int(meta.get("invocations", 0)), "iterations": int(meta.get("iterations", 0)),
        "inner_iterations": json.loads(meta.get("inner", "{}")),
        "languages": langs, "baseline": BASELINE,
        "machine": machine(), "toolchain": toolchain, "builds": builds,
        "load": {"start": read(os.path.join(raw, "load-start.txt")).strip(),
                 "end": read(os.path.join(raw, "load-end.txt")).strip()},
        "order": [" ".join(o) for o in order],
        "runs": runs,
    }
    with open(out, "w") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")


# ---- statistics

def pooled_mean(invocations, skip_first=False):
    xs = [t for inv in invocations for t in (inv[1:] if skip_first else inv)]
    return sum(xs) / len(xs)


def geomean(xs):
    return math.exp(sum(math.log(x) for x in xs) / len(xs))


def percentile(sorted_xs, p):
    k = (len(sorted_xs) - 1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return sorted_xs[lo] + (sorted_xs[hi] - sorted_xs[lo]) * (k - lo)


def analyse(doc):
    rng = random.Random(SEED)
    benches = [b for b in doc["runs"] if all(l in doc["runs"][b] for l in (SUBJECT, BASELINE))]
    rows, boot = [], {b: [] for b in benches}
    for b in benches:
        row = {"benchmark": b, "inner": doc["inner_iterations"].get(b)}
        invs = {}
        for lang in doc["languages"]:
            runs = doc["runs"][b].get(lang, [])
            invs[lang] = [r["iterations_us"] for r in runs if r["iterations_us"]]
            xs = [t for inv in invs[lang] for t in inv]
            rss = [r["peak_rss_bytes"] for r in runs if r["peak_rss_bytes"]]
            row[lang] = {"mean": statistics.fmean(xs), "sd": statistics.stdev(xs) if len(xs) > 1 else 0.0,
                         "n": len(xs), "invocations": len(invs[lang]),
                         "peak_rss_mib": max(rss) / 2**20 if rss else None,
                         "mean_after_first": pooled_mean(invs[lang], True) if all(len(i) > 1 for i in invs[lang]) else None}
        row["ratio"] = row[SUBJECT]["mean"] / row[BASELINE]["mean"]
        # Each invocation as (sum, count): a resample's pooled mean is the sum of sums over counts.
        sums = {lang: [(sum(inv), len(inv)) for inv in invs[lang]] for lang in (SUBJECT, BASELINE)}
        for _ in range(BOOTSTRAP):
            m = {}
            for lang, v in sums.items():
                picks = [v[rng.randrange(len(v))] for _ in v]
                m[lang] = sum(s for s, _ in picks) / sum(c for _, c in picks)
            boot[b].append(m[SUBJECT] / m[BASELINE])
        s = sorted(boot[b])
        row["ratio_ci"] = [percentile(s, 0.025), percentile(s, 0.975)]
        rows.append(row)
    g = geomean([r["ratio"] for r in rows])
    gs = sorted(geomean([boot[b][i] for b in benches]) for i in range(BOOTSTRAP))
    after = None
    if all(r[SUBJECT]["mean_after_first"] and r[BASELINE]["mean_after_first"] for r in rows):
        after = geomean([r[SUBJECT]["mean_after_first"] / r[BASELINE]["mean_after_first"] for r in rows])
    single = min(min(r[l]["invocations"] for l in (SUBJECT, BASELINE)) for r in rows) < 2
    return {"rows": rows, "geomean": g, "geomean_ci": [percentile(gs, 0.025), percentile(gs, 0.975)],
            "geomean_after_first": after, "single_invocation": single, "complete": len(rows) == 14}


# ---- rendering

def fmt_us(us):
    return f"{us / 1000:,.2f} ms" if us >= 1000 else f"{us:,.0f} µs"


def fmt_pm(cell):
    if cell["n"] < 2:
        return f"{fmt_us(cell['mean'])} (one sample)"
    return f"{fmt_us(cell['mean'])} ± {fmt_us(cell['sd'])}"


def summary_lines(doc):
    m, t = doc["machine"], doc["toolchain"]
    return [
        ("Machine", " ".join(x for x in [m.get("model", ""), m.get("cpu", "")] if x)
         + (f", {m.get('performance_cores')}P + {m.get('efficiency_cores')}E cores" if m.get("performance_cores") else "")
         + (f", {int(m['memory_bytes']) / 2**30:.0f} GiB" if m.get("memory_bytes") else "")),
        ("OS", m.get("macos") and f"macOS {m['macos']}" or f"{m['os']} {m['os_release']}"),
        ("Power", "; ".join(m.get("power", []) + m.get("sleep_setting", []) + m.get("low_power_mode", []))),
        ("sysl", t.get("sysl", "")),
        ("clang", "".join(t.get("clang", []))),
        ("sysl build", doc["builds"].get("sysl", {}).get("command", "")),
        ("C++ build", doc["builds"].get("cpp", {}).get("command", "")),
        ("Upstream", f"{doc['upstream']['url']} at {doc['upstream']['commit']}"),
        ("Runs", f"{doc['invocations']} invocations × {doc['iterations']} iterations per benchmark and "
                 f"language, languages alternating, one thread; started {doc['started']}, finished {doc['finished']}"),
        ("Load", f"start: {doc['load']['start']} / end: {doc['load']['end']}"),
    ]


def ci_text(a, ci):
    return "n/a (one invocation)" if a["single_invocation"] else f"{ci[0]:.3f}–{ci[1]:.3f}"


def render_md(doc, a):
    out = ["# Are We Fast Yet: sysl and C++", "",
           "Generated by `scripts/report.py` from the raw JSON beside this file; METHODOLOGY.md says how "
           "each number is made and why.", ""]
    if a["single_invocation"]:
        out += ["**A smoke run (one invocation): no interval can be computed, and the numbers prove only "
                "that the pipeline works. Not a result.**", ""]
    out += [f"**sysl / C++, geometric mean over {len(a['rows'])} benchmarks: {a['geomean']:.3f}** "
            f"(95% bootstrap interval {ci_text(a, a['geomean_ci'])}). Below 1 is sysl faster.", ""]
    if a["geomean_after_first"]:
        out += [f"Without each invocation's first iteration: {a['geomean_after_first']:.3f}.", ""]
    out += ["| benchmark | inner | sysl, mean ± sd per iteration | C++, mean ± sd per iteration | sysl / C++ | 95% interval | peak RSS sysl / C++ |",
            "|---|---:|---:|---:|---:|---:|---:|"]
    for r in a["rows"]:
        rss = (f"{r[SUBJECT]['peak_rss_mib']:.1f} / {r[BASELINE]['peak_rss_mib']:.1f} MiB"
               if r[SUBJECT]["peak_rss_mib"] and r[BASELINE]["peak_rss_mib"] else "")
        out.append(f"| {r['benchmark']} | {r['inner']} | {fmt_pm(r[SUBJECT])} | {fmt_pm(r[BASELINE])} | "
                   f"{r['ratio']:.3f} | {ci_text(a, r['ratio_ci'])} | {rss} |")
    out += ["", "| | |", "|---|---|"]
    out += [f"| {k} | {v.replace('|', '/')} |" for k, v in summary_lines(doc)]
    for lang in doc["languages"]:
        b = doc["builds"].get(lang, {})
        out.append(f"| {LANG_NAMES.get(lang, lang)} binary, build time | {b.get('binary_bytes') or '?'} bytes, "
                   f"{b.get('seconds', float('nan')):.1f} s |")
    return "\n".join(out) + "\n"


def svg_chart(a):
    rows = a["rows"]
    label_w, right, top, row_h, bar_h = 110, 70, 34, 28, 14
    plot_w = 560
    width = label_w + plot_w + right
    height = top + row_h * len(rows) + 40
    hi = max([r["ratio_ci"][1] for r in rows] + [r["ratio"] for r in rows] + [1.0, a["geomean"]])
    step = 0.25 if hi <= 2 else 0.5 if hi <= 4 else 1.0
    x_max = math.ceil(hi * 1.05 / step) * step
    x = lambda v: label_w + v / x_max * plot_w
    p = [f'<svg viewBox="0 0 {width} {height}" role="img" aria-labelledby="chart-title chart-desc" '
         f'xmlns="http://www.w3.org/2000/svg">',
         '<title id="chart-title">sysl / C++ time ratio per benchmark</title>',
         f'<desc id="chart-desc">Bars give each benchmark\'s ratio of mean iteration time, sysl over C++, '
         f'with 95% bootstrap intervals; 1 is parity, below 1 is sysl faster. Geometric mean '
         f'{a["geomean"]:.3f}.</desc>']
    v = 0.0
    while v <= x_max + 1e-9:
        p.append(f'<line class="grid" x1="{x(v):.1f}" x2="{x(v):.1f}" y1="{top - 8}" y2="{height - 34}"/>')
        p.append(f'<text class="tick" x="{x(v):.1f}" y="{height - 18}" text-anchor="middle">{v:g}×</text>')
        v += step
    for i, r in enumerate(rows):
        yc = top + i * row_h + row_h / 2
        w = x(r["ratio"]) - x(0)
        lo, hi_ = r["ratio_ci"]
        tip = (f"{r['benchmark']}: sysl / C++ = {r['ratio']:.3f} (95% {lo:.3f}–{hi_:.3f}); "
               f"sysl {fmt_pm(r[SUBJECT])}, C++ {fmt_pm(r[BASELINE])}")
        p.append(f'<g class="row"><title>{html.escape(tip)}</title>'
                 f'<rect class="hit" x="0" y="{yc - row_h / 2:.1f}" width="{width}" height="{row_h}"/>'
                 f'<text class="label" x="{label_w - 10}" y="{yc + 4:.1f}" text-anchor="end">{r["benchmark"]}</text>'
                 f'<path class="bar" d="M{x(0):.1f},{yc - bar_h / 2:.1f} h{max(w - 4, 0):.1f} '
                 f'a4,4 0 0 1 4,4 v{bar_h - 8} a4,4 0 0 1 -4,4 h{-max(w - 4, 0):.1f} z"/>'
                 f'<line class="err" x1="{x(lo):.1f}" x2="{x(hi_):.1f}" y1="{yc:.1f}" y2="{yc:.1f}"/>'
                 f'<line class="err" x1="{x(lo):.1f}" x2="{x(lo):.1f}" y1="{yc - 4:.1f}" y2="{yc + 4:.1f}"/>'
                 f'<line class="err" x1="{x(hi_):.1f}" x2="{x(hi_):.1f}" y1="{yc - 4:.1f}" y2="{yc + 4:.1f}"/>'
                 f'<text class="value" x="{max(x(hi_), x(r["ratio"])) + 6:.1f}" y="{yc + 4:.1f}">{r["ratio"]:.2f}</text></g>')
    p.append(f'<line class="parity" x1="{x(1):.1f}" x2="{x(1):.1f}" y1="{top - 12}" y2="{height - 34}"/>')
    p.append(f'<text class="ref" x="{x(1):.1f}" y="{top - 16}" text-anchor="middle">C++ = 1</text>')
    p.append(f'<line class="geo" x1="{x(a["geomean"]):.1f}" x2="{x(a["geomean"]):.1f}" y1="{top - 12}" y2="{height - 34}"/>')
    anchor = "start" if a["geomean"] >= 1 else "end"
    dx = 6 if a["geomean"] >= 1 else -6
    p.append(f'<text class="ref geo-label" x="{x(a["geomean"]) + dx:.1f}" y="{top - 16}" text-anchor="{anchor}">'
             f'geomean {a["geomean"]:.3f}</text>')
    p.append("</svg>")
    return "\n".join(p)


CSS = """
:root{--surface:#fcfcfb;--panel:#f4f3f0;--ink:#0b0b0b;--ink-2:#45443f;--muted:#898781;--grid:#e4e2dd;
--bar:#2a78d6;--err:#0b0b0b;--geo:#b4472b}
@media (prefers-color-scheme:dark){:root{--surface:#1a1a19;--panel:#232321;--ink:#f0efec;--ink-2:#c4c2bc;
--muted:#898781;--grid:#383835;--bar:#3987e5;--err:#f0efec;--geo:#e8775a}}
*{box-sizing:border-box}
body{margin:0;background:var(--surface);color:var(--ink);font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",
Helvetica,Arial,sans-serif}
main{max-width:980px;margin:0 auto;padding:32px 16px 64px}
h1{font-size:26px;margin:0 0 4px}h2{font-size:18px;margin:36px 0 10px}
.lede{color:var(--ink-2);margin:0 0 24px}
.headline{background:var(--panel);border-radius:10px;padding:18px 20px;margin:0 0 24px}
.headline .big{font-size:34px;font-weight:650;font-variant-numeric:tabular-nums}
.headline .sub{color:var(--ink-2)}
.warn{border-left:4px solid var(--geo);padding:10px 14px;background:var(--panel);margin:0 0 20px}
figure{margin:0}svg{width:100%;height:auto;display:block}
svg text{font:12px -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;fill:var(--ink-2)}
svg .label{fill:var(--ink)}svg .tick,svg .ref{fill:var(--muted)}svg .geo-label{fill:var(--geo)}
svg .value{font-variant-numeric:tabular-nums}
svg .grid{stroke:var(--grid);stroke-width:1}svg .bar{fill:var(--bar)}
svg .err{stroke:var(--err);stroke-width:1.5}
svg .parity{stroke:var(--muted);stroke-width:1.5}svg .geo{stroke:var(--geo);stroke-width:2;stroke-dasharray:5 4}
svg .hit{fill:transparent}svg .row:hover .hit{fill:var(--panel)}
figcaption{color:var(--muted);font-size:13px;margin-top:6px}
.scroll{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:14px}
th,td{padding:6px 10px;border-bottom:1px solid var(--grid);text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left}
th{color:var(--ink-2);font-weight:600}
dl{display:grid;grid-template-columns:max-content minmax(0,1fr);gap:6px 16px;margin:0}
@media (max-width:600px){dl{display:block}dd{margin:0 0 10px}}
main>*{min-width:0;max-width:100%}
dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px}
"""

METHOD = [
    "Fourteen benchmarks of upstream's suite, each at upstream's inner iterations (rebench.conf).",
    "C++ is upstream's port, unmodified, built by upstream's build.sh; the sysl port follows upstream's "
    "porting guidelines (SOURCES.md lists every difference from the C++ and Java ports, and why).",
    "Both languages are compiled by the same clang: -O3, whole-program LTO, this machine's processor, "
    "no fused multiply-add.",
    "Each invocation is one process running upstream's harness for the iterations below; the harness "
    "times each iteration itself with a monotonic clock and checks the benchmark's result every time.",
    "Per benchmark: the mean of all iterations of all invocations, ± their sample standard deviation. "
    "The ratio is sysl's mean over C++'s; the headline is the geometric mean of the ratios.",
    "Intervals: 95% percentile bootstrap, resampling whole invocations, 10,000 replicates, fixed seed.",
    "One thread, the machine on AC power, kept awake (caffeinate), and otherwise idle.",
]


def render_html(doc, a):
    rows = []
    for r in a["rows"]:
        rows.append(f"<tr><td>{r['benchmark']}</td><td>{r['inner']}</td><td>{html.escape(fmt_pm(r[SUBJECT]))}</td>"
                    f"<td>{html.escape(fmt_pm(r[BASELINE]))}</td><td>{r['ratio']:.3f}</td>"
                    f"<td>{html.escape(ci_text(a, r['ratio_ci']))}</td></tr>")
    details = "".join(f"<dt>{html.escape(k)}</dt><dd>{html.escape(v)}</dd>" for k, v in summary_lines(doc))
    warn = ('<p class="warn"><strong>Smoke run.</strong> One invocation: no interval can be computed, and the '
            'numbers prove only that the pipeline works. Not a result.</p>') if a["single_invocation"] else ""
    after = (f" Without each invocation's first iteration: {a['geomean_after_first']:.3f}."
             if a["geomean_after_first"] else "")
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>AWFY: sysl and C++</title><style>{CSS}</style></head>
<body><main>
<h1>Are We Fast Yet: sysl and C++</h1>
<p class="lede">The fourteen benchmarks of Marr, Daloze and Mössenböck's cross-language suite (DLS 2016),
sysl against upstream's own C++ port. Generated from the raw JSON by <code>scripts/report.py</code>.</p>
{warn}
<div class="headline"><div class="big">{a['geomean']:.3f}×</div>
<div class="sub">sysl time / C++ time, geometric mean over {len(a['rows'])} benchmarks; 95% bootstrap interval
{html.escape(ci_text(a, a['geomean_ci']))}. Below 1 is sysl faster.{after}</div></div>
<h2>Ratio per benchmark</h2>
<figure>{svg_chart(a)}
<figcaption>Bar: mean iteration time of sysl over C++. Whisker: 95% bootstrap interval. Solid line: parity;
dashed: the geometric mean. Hover a row for its times.</figcaption></figure>
<h2>Times per iteration</h2>
<div class="scroll"><table><thead><tr><th>benchmark</th><th>inner</th><th>sysl, mean ± sd</th><th>C++, mean ± sd</th>
<th>sysl / C++</th><th>95% interval</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>
<h2>How it was measured</h2>
<ul>{''.join(f'<li>{html.escape(s)}</li>' for s in METHOD)}</ul>
<p>The full reasoning, and the threats to validity, are in METHODOLOGY.md.</p>
<h2>Machine and toolchain</h2>
<dl>{details}</dl>
</main></body></html>
"""


def main():
    if len(sys.argv) >= 5 and sys.argv[1] == "collect":
        collect(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:])
    elif len(sys.argv) == 5 and sys.argv[1] == "render":
        with open(sys.argv[2]) as f:
            doc = json.load(f)
        a = analyse(doc)
        with open(sys.argv[3], "w") as f:
            f.write(render_md(doc, a))
        with open(sys.argv[4], "w") as f:
            f.write(render_html(doc, a))
        print(f"geomean sysl/C++ {a['geomean']:.3f}  95% {ci_text(a, a['geomean_ci'])}  ({len(a['rows'])} benchmarks)")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
