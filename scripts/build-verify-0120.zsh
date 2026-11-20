#!/bin/zsh
# bench-0120: build every program and AWFY with sysl 0.12.0, then verify every output.
unset SYSL_DEV SYSL_DEV_LIB SYSL_DEV_COMMIT
repo=/Users/ed/dev/sysl-lang/bench-results-0120
rc=0
print "== sysl: $(sysl --version)"
print "== main: build ($(date))"
zsh $repo/scripts/build.zsh || rc=1
print "== main: verify ($(date))"
zsh $repo/scripts/run.zsh --verify || rc=1
print "== awfy: build ($(date))"
(cd $repo/awfy && zsh scripts/run.zsh build) || rc=1
print "== awfy: verify ($(date))"
(cd $repo/awfy && zsh scripts/run.zsh verify) || rc=1
print "== done rc=$rc ($(date))"
exit $rc
