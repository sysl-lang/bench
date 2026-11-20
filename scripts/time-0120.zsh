#!/bin/zsh
# bench-0120: the one timing job. Verifies and times every program in every language with sysl
# 0.12.0, then times AWFY (sysl 0.12.0 and C++).
unset SYSL_DEV SYSL_DEV_LIB SYSL_DEV_COMMIT
repo=/Users/ed/dev/sysl-lang/bench-results-0120
rc=0
print "== sysl: $(sysl --version)"
print "== main: verify and time ($(date))"
zsh $repo/scripts/run.zsh || rc=1
print "== awfy: time ($(date))"
(cd $repo/awfy && zsh scripts/run.zsh time) || rc=1
print "== done rc=$rc ($(date))"
exit $rc
