#!/usr/bin/env bash
# Self-test for scripts/leak-scan.sh: proves it FAILS (not skips) when a
# required build output is missing, passes when all outputs are clean, and
# still fails when a planted old-brand reference is present. Runs entirely
# inside a throwaway git repo under mktemp -d.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEAK_SCAN="$REPO_ROOT/scripts/leak-scan.sh"

TMPDIR=""
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

TMPDIR=$(mktemp -d)
WORKDIR="$TMPDIR/work"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

git init -q

mkdir -p scripts
cp "$LEAK_SCAN" scripts/leak-scan.sh
chmod +x scripts/leak-scan.sh

echo "A clean fictional demo file about Patient Zero and vitamin D." > README.md

git add scripts/leak-scan.sh README.md
git -c user.email="demo@example.com" -c user.name="Demo User" commit -q -m "initial clean commit"

FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# (a) no build outputs -> non-zero, mentions "required build output missing"
set +e
OUT_A=$(bash scripts/leak-scan.sh 2>&1)
RC_A=$?
set -e
if [ "$RC_A" -ne 0 ] && echo "$OUT_A" | grep -q "required build output missing"; then
    pass "(a) no build outputs fails with required-output message"
else
    fail "(a) no build outputs fails with required-output message (rc=$RC_A)"
    echo "$OUT_A"
fi

# (b) only some outputs present -> still non-zero, names the missing one
mkdir -p dist
echo "<html>clean</html>" > dist/index.html
set +e
OUT_B=$(bash scripts/leak-scan.sh 2>&1)
RC_B=$?
set -e
if [ "$RC_B" -ne 0 ] && echo "$OUT_B" | grep -q "required build output missing: space/dist"; then
    pass "(b) partial build outputs still fails and names the missing one"
else
    fail "(b) partial build outputs still fails and names the missing one (rc=$RC_B)"
    echo "$OUT_B"
fi

# (c) all four outputs present with clean contents -> exits 0, "LEAK SCAN PASSED"
mkdir -p space/dist flutter_app/build/web flutter_app/build/app/outputs/flutter-apk
echo "<html>clean</html>" > space/dist/index.html
echo "<html>clean</html>" > flutter_app/build/web/index.html

python3 - "flutter_app/build/app/outputs/flutter-apk/app-debug.apk" <<'PYEOF'
import sys
import zipfile

apk_path = sys.argv[1]
with zipfile.ZipFile(apk_path, "w") as zf:
    zf.writestr("assets/clean.txt", "nothing to see here, fictional patient data only")
PYEOF

set +e
OUT_C=$(bash scripts/leak-scan.sh 2>&1)
RC_C=$?
set -e
if [ "$RC_C" -eq 0 ] && echo "$OUT_C" | grep -q "LEAK SCAN PASSED"; then
    pass "(c) all outputs present and clean passes"
else
    fail "(c) all outputs present and clean passes (rc=$RC_C)"
    echo "$OUT_C"
fi

# (d) all present but a planted brand string inside flutter_app/build/web -> non-zero
BRAND_P1="nost"
BRAND_P2="avia"
echo "leftover reference to ${BRAND_P1}${BRAND_P2} health" > flutter_app/build/web/leak.txt

set +e
OUT_D=$(bash scripts/leak-scan.sh 2>&1)
RC_D=$?
set -e
if [ "$RC_D" -ne 0 ]; then
    pass "(d) planted brand string in build output fails"
else
    fail "(d) planted brand string in build output fails (rc=$RC_D)"
    echo "$OUT_D"
fi

rm -f flutter_app/build/web/leak.txt

if [ "$FAIL" -ne 0 ]; then
    echo "TEST-LEAK-SCAN: one or more cases FAILED"
    exit 1
fi

echo "TEST-LEAK-SCAN: all cases PASSED"
