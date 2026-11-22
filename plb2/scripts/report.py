#!/usr/bin/env python3
"""Writes results/report.md and results/report.html (self-contained) from results/raw/*.json,
results/meta.json and results/verify.tsv.

Each cell is hyperfine's mean wall time ± its standard deviation, the ratio of that mean to C's for
the same program, and the CPU time (user + system) beside it. A language's geometric mean is over the
programs it has a time for, and says so when that is fewer than all four. A cell whose output was not
C's is marked, and left out of the geometric mean.
"""

import html
import json
import math
import os
import pathlib

PLB2 = pathlib.Path(__file__).resolve().parent.parent
RESULTS = pathlib.Path(os.environ.get("PLB2_RESULTS") or PLB2 / "results")
PROGRAMS = ["nqueen", "matmul", "sudoku", "bedcov"]
LANGS = ["c", "rust", "zig", "swift", "nim", "d", "sysl"]
NAMES = {"c": "C", "rust": "Rust", "zig": "Zig", "swift": "Swift", "nim": "Nim", "d": "D", "sysl": "sysl"}


def load():
    meta = json.loads((RESULTS / "meta.json").read_text())
    verdict = {}
    for line in (RESULTS / "verify.tsv").read_text().splitlines()[1:]:
        prog, lang, v, note = (line.split("\t") + [""])[:4]
        verdict[prog, lang] = (v, note)
    cell = {}
    for f in (RESULTS / "raw").glob("*.json"):
        prog, lang = f.stem.split("-", 1)
        s = json.loads(f.read_text())["results"][0]["summary"]
        wall = s["time_wall_clock"]
        cell[prog, lang] = {"mean": wall["mean"], "sd": wall["stddev"] or 0.0,
                            "cpu": s["time_user"]["mean"] + s["time_system"]["mean"], "runs": wall["count"]}
    return meta, verdict, cell


def ratios(cell, verdict):
    ratio = {}
    for (prog, lang), c in cell.items():
        base = cell.get((prog, "c"))
        if base:
            ratio[prog, lang] = c["mean"] / base["mean"]
    geo = {}
    for lang in LANGS:
        rs = [ratio[p, lang] for p in PROGRAMS
              if (p, lang) in ratio and verdict.get((p, lang), ("",))[0] in ("ok", "format")]
        if rs:
            geo[lang] = (math.exp(sum(map(math.log, rs)) / len(rs)), len(rs))
    return ratio, geo


def absent_text(verdict, prog, lang):
    v = verdict.get((prog, lang), ("",))[0]
    return {"failed": "does not build", "absent": "no upstream program"}.get(v, "not run")


def markdown(meta, verdict, cell, ratio, geo):
    out = [f"# plb2 results — {meta['date']}", "",
           f"{meta['cpu']} ({meta['model']}), {meta['os']}; {meta['hyperfine']}, `-N --warmup 1`, "
           f"order shuffled from seed {meta['seed']}.", "",
           "Mean wall time ± standard deviation in seconds, and the ratio to C (lower is faster).", "",
           "| program | " + " | ".join(NAMES[l] for l in LANGS) + " |",
           "|---|" + "---:|" * len(LANGS)]
    notes = []
    for prog in PROGRAMS:
        row = [prog]
        for lang in LANGS:
            c = cell.get((prog, lang))
            if not c:
                row.append(absent_text(verdict, prog, lang))
                continue
            v, note = verdict.get((prog, lang), ("", ""))
            mark = ""
            if v in ("format", "WRONG"):
                notes.append(f"{NAMES[lang]} {prog}: {'WRONG ANSWER — ' if v == 'WRONG' else ''}{note}")
                mark = f" [{len(notes)}]"
            row.append(f"{c['mean']:.3f} ± {c['sd']:.3f} ({ratio.get((prog, lang), float('nan')):.2f}×){mark}")
        out.append("| " + " | ".join(row) + " |")
    row = ["**geomean vs C**"]
    for lang in LANGS:
        if lang in geo:
            g, n = geo[lang]
            row.append(f"**{g:.2f}×**" + ("" if n == len(PROGRAMS) else f" (over {n})"))
        else:
            row.append("—")
    out.append("| " + " | ".join(row) + " |")
    out += ["", "CPU time (user + system), mean seconds:", "",
            "| program | " + " | ".join(NAMES[l] for l in LANGS) + " |",
            "|---|" + "---:|" * len(LANGS)]
    for prog in PROGRAMS:
        out.append("| " + " | ".join([prog] + [f"{cell[prog, l]['cpu']:.3f}"
                                               if (prog, l) in cell else "—" for l in LANGS]) + " |")
    if notes:
        out += ["", *[f"[{i}] {n}" for i, n in enumerate(notes, 1)]]
    out += ["", "Toolchains:", ""] + [f"- {NAMES[l]}: {meta['toolchains'].get(l, '?')} — flags "
                                       f"`{meta['flags'].get(l, '')}`" for l in LANGS]
    return "\n".join(out) + "\n"


CSS = """
:root { color-scheme: light dark; --fg: #1d1d1f; --bg: #fff; --muted: #6e6e73; --line: #d2d2d7;
        --bar: #3a6fd8; --c: #8a8a8e; --sysl: #d8743a; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #f2f2f7; --bg: #1c1c1e; --muted: #98989d; --line: #3a3a3c; --bar: #6a9bf4;
          --c: #8e8e93; --sysl: #f0955d; } }
body { font: 14px/1.45 -apple-system, system-ui, sans-serif; color: var(--fg); background: var(--bg);
       max-width: 70rem; margin: 2rem auto; padding: 0 1rem; }
h1 { font-size: 1.4rem; } h2 { font-size: 1.1rem; margin-top: 2rem; }
p, li { color: var(--muted); }
table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
th, td { padding: .3rem .5rem; border-bottom: 1px solid var(--line); text-align: right; }
th:first-child, td:first-child { text-align: left; }
.bars td { text-align: left; }
.bar { height: .8rem; background: var(--bar); border-radius: 2px; display: inline-block;
       vertical-align: middle; }
.bar.c { background: var(--c); } .bar.sysl { background: var(--sysl); }
.na { color: var(--muted); font-style: italic; }
"""


def html_report(meta, verdict, cell, ratio, geo, md_notes):
    e = html.escape
    h = ["<!doctype html><html lang=en><meta charset=utf-8>",
         "<meta name=viewport content='width=device-width, initial-scale=1'>",
         f"<title>plb2 results</title><style>{CSS}</style>",
         f"<h1>plb2 results — {e(meta['date'])}</h1>",
         f"<p>{e(meta['cpu'])} ({e(meta['model'])}), {e(meta['os'])}; {e(meta['hyperfine'])}, "
         f"<code>-N --warmup 1</code>, order shuffled from seed {meta['seed']}. Mean wall time ± standard "
         "deviation in seconds; the ratio is to C's mean (lower is faster).</p>",
         "<table><tr><th>program</th>" + "".join(f"<th>{NAMES[l]}</th>" for l in LANGS) + "</tr>"]
    for prog in PROGRAMS:
        h.append(f"<tr><td>{prog}</td>")
        for lang in LANGS:
            c = cell.get((prog, lang))
            if not c:
                h.append(f"<td class=na>{absent_text(verdict, prog, lang)}</td>")
                continue
            v = verdict.get((prog, lang), ("",))[0]
            flag = " <b>wrong answer</b>" if v == "WRONG" else (" *" if v == "format" else "")
            h.append(f"<td>{c['mean']:.3f} ± {c['sd']:.3f}<br>{ratio.get((prog, lang), float('nan')):.2f}×"
                     f"{flag}</td>")
        h.append("</tr>")
    h.append("<tr><th>geomean vs C</th>" + "".join(
        f"<th>{geo[l][0]:.2f}×{'' if geo[l][1] == len(PROGRAMS) else f' (over {geo[l][1]})'}</th>"
        if l in geo else "<th>—</th>" for l in LANGS) + "</tr></table>")
    if md_notes:
        h.append("<p>* " + "<br>".join(e(n) for n in md_notes) + "</p>")
    top = max(ratio.values()) if ratio else 1.0
    for prog in PROGRAMS:
        h.append(f"<h2>{prog} — time relative to C</h2><table class=bars>")
        for lang in LANGS:
            if (prog, lang) not in ratio:
                continue
            r = ratio[prog, lang]
            cls = lang if lang in ("c", "sysl") else ""
            h.append(f"<tr><td style='width:6rem'>{NAMES[lang]}</td><td><span class='bar {cls}' "
                     f"style='width:{max(r / top * 85, .5):.1f}%'></span> {r:.2f}×</td></tr>")
        h.append("</table>")
    h.append("<h2>Toolchains and flags</h2><ul>" + "".join(
        f"<li>{NAMES[l]}: {e(meta['toolchains'].get(l, '?'))} — <code>{e(meta['flags'].get(l, ''))}</code></li>"
        for l in LANGS) + "</ul></html>")
    return "\n".join(h) + "\n"


def main():
    meta, verdict, cell = load()
    ratio, geo = ratios(cell, verdict)
    md = markdown(meta, verdict, cell, ratio, geo)
    notes = [n for n in md.splitlines() if n.startswith("[")]
    (RESULTS / "report.md").write_text(md)
    (RESULTS / "report.html").write_text(html_report(meta, verdict, cell, ratio, geo, notes))
    print(md)


if __name__ == "__main__":
    main()
