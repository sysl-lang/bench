#!/bin/zsh
# Checks the toolchain and prints its versions, fetches upstream at the pinned commit into
# build/upstream, and checks that every upstream file kept here is upstream's, byte for byte.
# Exits non-zero on the first thing missing or different.

source ${0:A:h}/config.zsh
setopt err_exit pipe_fail
failed=0

need() {  # <what> <how to install>
  print -u2 "MISSING  $1 — install: $2"
  failed=1
}

version_at_least() {  # <have> <want>, dotted numbers
  local -a have want
  have=(${(s:.:)1}) want=(${(s:.:)2})
  local i
  for i in 1 2 3; do
    (( ${have[i]:-0} > ${want[i]:-0} )) && return 0
    (( ${have[i]:-0} < ${want[i]:-0} )) && return 1
  done
  return 0
}

print "== toolchain"
if [[ -x $SYSL ]]; then
  sysl_version=${${(z)$($SYSL --version)}[2]}
  print "sysl     $SYSL  ($sysl_version)"
  version_at_least $sysl_version $SYSL_MIN ||
    need "sysl $SYSL_MIN or later (found $sysl_version)" "brew install sysl-lang/tap/sysl, or brew upgrade sysl"
else
  need "sysl $SYSL_MIN or later" "brew install sysl-lang/tap/sysl"
fi
if [[ -x $CLANG && -x $CLANGXX ]]; then
  print "clang    $CLANG  ($($CLANG --version | head -1))"
  print "clang++  $CLANGXX"
else
  need "clang and clang++" "xcode-select --install (macOS), or your distribution's clang package"
fi
if command -v python3 >/dev/null; then
  print "python3  $(command -v python3)  ($(python3 --version))"
else
  need "python3 (3.8 or later; standard library only)" "xcode-select --install, or python.org"
fi
if (( ${LANGS[(Ie)zig]} )); then
  if [[ -n $ZIG && -x $ZIG ]]; then
    print "zig      $ZIG  ($($ZIG version))"
  else
    need "zig 0.17 (the Zig column)" "brew install zig"
  fi
fi
if (( ${LANGS[(Ie)rust]} )); then
  if [[ -n $CARGO && -x $CARGO && -x ${CARGO:h}/rustc ]]; then
    print "cargo    $CARGO  ($(${CARGO:h}/rustc --version))"
  else
    need "cargo and rustc 1.94 or later (the Rust column; CARGO=<toolchain>/bin/cargo if not on PATH)" "rustup.rs"
  fi
fi
command -v git >/dev/null || need git "xcode-select --install"
command -v bash >/dev/null || need bash "upstream's build.sh is a bash script"
(( failed == 0 )) || return 1

# The published run's platform and versions (config.zsh). A difference is allowed, but its numbers
# are a different measurement: a different optimiser moves both columns.
[[ $(uname -sm) == "Darwin arm64" ]] ||
  print "WARNING: this is $(uname -sm); the track is tested only on macOS arm64 (METHODOLOGY.md, section 9). On Linux run.zsh's /usr/bin/time -l fails; on x86 clang reads -mcpu=native as generic x86-64."
[[ $sysl_version == $RECORDED_SYSL ]] ||
  print "WARNING: sysl $sysl_version, but the published run used sysl $RECORDED_SYSL; the results are not comparable with it"
[[ $($CLANG --version | head -1) == $RECORDED_CLANG ]] ||
  print "WARNING: $($CLANG --version | head -1), but the published run used $RECORDED_CLANG; the results are not comparable with it"

print "== upstream"
if [[ ! -d $UPSTREAM_DIR/.git ]]; then
  mkdir -p $BUILD
  git clone --quiet $UPSTREAM_URL $UPSTREAM_DIR
fi
if ! git -C $UPSTREAM_DIR cat-file -e $UPSTREAM_COMMIT^{commit} 2>/dev/null; then
  git -C $UPSTREAM_DIR fetch --quiet origin
fi
# -f discards any edit to a tracked file, so C++ is always built from upstream's own sources.
git -C $UPSTREAM_DIR checkout --quiet --force --detach $UPSTREAM_COMMIT
git -C $UPSTREAM_DIR clean --quiet -fdx
if [[ -n $(git -C $UPSTREAM_DIR status --porcelain --ignored) ]]; then
  print -u2 "build/upstream is not a clean checkout of $UPSTREAM_COMMIT:"
  git -C $UPSTREAM_DIR status --short --ignored >&2
  return 1
fi
print "upstream $UPSTREAM_URL at $(git -C $UPSTREAM_DIR rev-parse HEAD)"
print "upstream HEAD of its default branch: $(git -C $UPSTREAM_DIR rev-parse origin/HEAD 2>/dev/null)"

zsh ${0:A:h}/check-upstream.zsh
