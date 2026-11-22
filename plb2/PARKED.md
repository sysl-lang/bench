# plb2 track — state (removed when the track lands)

Branch `plb2`, worktree `/Users/ed/dev/sysl-lang/bench-plb2`. The design is README.md and
METHODOLOGY.md; this file holds only what is left.

- Scope (user, 2026-11-22): C, Rust, Zig, Swift, Nim, D (all upstream, unmodified, upstream's flags)
  and sysl (written, `written/sysl/`). No other ports.
- Done: the four sysl programs, verified against upstream C; build, verify, time, report and
  reproduce scripts; README, METHODOLOGY.
- Left: ONE timing run of `zsh plb2/reproduce.zsh` with the compiler the director names
  (`SYSL=<path>`), under marshal `--kind test --exclusive`; commit `results/`; explain any sysl cell
  over 1.3x C; delete this file.
