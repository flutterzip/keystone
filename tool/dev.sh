#!/bin/bash
# Development only: hot restarts the running app (tool/run.sh) into a state.
#   tool/dev.sh "signedIn,bag,tab=shop"     tool/dev.sh off
# It edits the default of LaunchHooks.start; `off` puts it back to empty. A
# test asserts the default is empty, so this cannot ship switched on.
cd "$(dirname "$0")/.."
V="$1"; [ "$V" = "off" ] && V=""
python3 -I - "$V" <<'PY'
import re, sys
p = 'lib/config/launch_hooks.dart'
s = open(p).read()
s2 = re.sub(r"defaultValue: '[^']*'", "defaultValue: '%s'" % sys.argv[1], s, count=1)
assert s2 != s or sys.argv[1] in s
open(p, 'w').write(s2)
PY
echo R > /tmp/keystone/fifo
