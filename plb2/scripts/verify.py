#!/usr/bin/env python3
"""Runs every built program once and checks its output against expected/, upstream C's output.

nqueen and bedcov must print exactly expected/<prog>.txt. matmul's first number must equal
expected/matmul.txt's to a relative 1e-8, or to the precision it was printed with where that is
coarser (D's writeln prints six significant digits). sudoku's output must hash to the first line
of expected/sudoku.sha256; output that differs only by leaving out the blank line after each puzzle
(upstream's Nim) must hash to the second, which is taken over the non-blank lines. A program that
prints nothing on stdout is read from stderr.

Every cell's verdict goes to build/verify.tsv: ok, format (right answer, printed differently),
WRONG, or the build status (failed, absent). report.py shows it beside the times.

    verify.py            check every cell build/status.tsv marks built; exit 1 on any WRONG
    verify.py --record   write expected/ from the C programs' output
"""

import hashlib
import pathlib
import re
import subprocess
import sys

PLB2 = pathlib.Path(__file__).resolve().parent.parent
BUILD = PLB2 / "build"
EXPECTED = PLB2 / "expected"
REL_TOL = 1e-8


def run(prog, lang):
    exe = BUILD / "bin" / prog / lang
    p = subprocess.run([str(exe)], capture_output=True, timeout=600)
    if p.returncode != 0:
        raise RuntimeError(f"exit status {p.returncode}: {p.stderr.decode(errors='replace')[:200]}")
    return p.stdout if p.stdout else p.stderr


def first_number(out):
    m = re.search(rb"-?\d+(\.(\d+))?([eE][-+]?\d+)?", out)
    if not m:
        raise RuntimeError(f"no number in output {out[:80]!r}")
    decimals = len(m.group(2) or b"") if not m.group(3) else None
    return float(m.group(0)), decimals


def sha(b):
    return hashlib.sha256(b).hexdigest()


def solutions(out):
    return b"".join(line + b"\n" for line in out.split(b"\n") if line)


def record():
    EXPECTED.mkdir(exist_ok=True)
    for prog in ("nqueen", "matmul", "bedcov"):
        (EXPECTED / f"{prog}.txt").write_bytes(run(prog, "c"))
    out = run("sudoku", "c")
    (EXPECTED / "sudoku.sha256").write_text(f"{sha(out)}\n{sha(solutions(out))}\n")
    print(f"recorded expected/ from build/bin/*/c ({out.count(b'\n')} sudoku lines)")


def check(prog, out):
    """Answers (verdict, note)."""
    if prog == "matmul":
        want, _ = first_number((EXPECTED / "matmul.txt").read_bytes())
        got, decimals = first_number(out)
        tol = REL_TOL * abs(want)
        if abs(got - want) <= tol:
            return "ok", ""
        if decimals is not None and abs(got - want) <= 0.5 * 10.0 ** -decimals:
            return "format", f"prints {got!r}: right to the {decimals} decimal(s) printed"
        return "WRONG", f"{got!r} is not {want!r}"
    if prog == "sudoku":
        full, solved = (EXPECTED / "sudoku.sha256").read_text().split()
        if sha(out) == full:
            return "ok", ""
        if sha(solutions(out)) == solved:
            return "format", "the same solutions, without the blank line after each puzzle"
        return "WRONG", f"sha256 {sha(out)} ({out.count(b'\n')} lines)"
    want = (EXPECTED / f"{prog}.txt").read_bytes()
    if out == want:
        return "ok", ""
    return "WRONG", f"prints {out.strip()[:60].decode(errors='replace')}, C prints {want.strip()[:60].decode()}"


def main():
    if sys.argv[1:] == ["--record"]:
        record()
        return 0
    wrong = 0
    rows = ["program\tlanguage\tverdict\tnote"]
    for line in (BUILD / "status.tsv").read_text().splitlines()[1:]:
        prog, lang, state, _ = line.split("\t")
        if state != "built":
            verdict, note = state, ""
        else:
            try:
                verdict, note = check(prog, run(prog, lang))
            except Exception as e:
                verdict, note = "WRONG", str(e)
        wrong |= verdict == "WRONG"
        rows.append(f"{prog}\t{lang}\t{verdict}\t{note}")
        print(f"{verdict:7} {prog}/{lang}" + (f": {note}" if note else ""))
    (BUILD / "verify.tsv").write_text("\n".join(rows) + "\n")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
