#!/usr/bin/env bash
# CI analyzer gate: runs `flutter analyze` across flutter_app and every Flutter/Dart
# package under packages/, and fails the build if there are any errors or warnings,
# or if flutter_app's info count exceeds the recorded baseline.
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BASELINE_FILE="flutter_app/analyze-baseline.txt"
BASELINE=$(tr -d '[:space:]' < "$BASELINE_FILE")

FAIL=0

analyze_target() {
    local target="$1"
    local enforce_baseline="$2"

    echo "== flutter analyze: $target =="

    pushd "$target" > /dev/null
    OUTPUT=$(flutter analyze --no-fatal-infos 2>&1) || true
    popd > /dev/null

    echo "$OUTPUT"

    local errors warnings infos
    errors=$(grep -cE '^\s*error •' <<< "$OUTPUT" || true)
    warnings=$(grep -cE '^\s*warning •' <<< "$OUTPUT" || true)
    infos=$(grep -cE '^\s*info •' <<< "$OUTPUT" || true)

    echo "-- $target: errors=$errors warnings=$warnings infos=$infos --"

    if [ "$errors" -gt 0 ] || [ "$warnings" -gt 0 ]; then
        echo "FAIL: $target has $errors error(s) and $warnings warning(s)."
        FAIL=1
    fi

    if [ "$enforce_baseline" = "true" ] && [ "$infos" -gt "$BASELINE" ]; then
        echo "FAIL: $target has $infos info(s), exceeding baseline of $BASELINE."
        FAIL=1
    fi
}

analyze_target "flutter_app" "true"

# Only gate packages that flutter_app actually depends on via a local path —
# other packages/ entries may be unused/in-progress and shouldn't block CI.
for pkg_path in $(grep -oE '\.\./packages/[a-zA-Z0-9_-]+' flutter_app/pubspec.yaml | sort -u); do
    pkg="packages/$(basename "$pkg_path")"
    if [ -f "$pkg/pubspec.yaml" ] && grep -q "sdk: flutter" "$pkg/pubspec.yaml"; then
        analyze_target "$pkg" "false"
    fi
done

if [ "$FAIL" -ne 0 ]; then
    echo "ANALYZE GATE FAILED"
    exit 1
fi

echo "ANALYZE GATE PASSED"
