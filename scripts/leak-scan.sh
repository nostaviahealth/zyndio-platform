#!/usr/bin/env bash
# Scans for leftover references to the old product brand name (assembled from
# parts so this script itself never contains the literal word) across:
#   - tracked file contents
#   - tracked file names
#   - web build output (dist/, space/dist/)
#   - Flutter web build output (flutter_app/build/web)
#   - an unzipped Flutter debug APK (flutter_app/build/app/outputs/flutter-apk/app-debug.apk)
# Exits 1 on any hit. Also exits 1 if any required build output is missing
# (missing outputs are treated as a scan failure, not silently skipped).
#
# LEAK_SCAN_FLUTTER=skip opts out of the two Flutter outputs (web build and
# the debug APK) when no Flutter-relevant path changed, printing a SKIPPED
# line for each instead of failing. Any other non-empty value is an error.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

LEAK_SCAN_FLUTTER="${LEAK_SCAN_FLUTTER:-}"
case "$LEAK_SCAN_FLUTTER" in
    "" | "skip") ;;
    *)
        echo "LEAK SCAN FAILED: unknown LEAK_SCAN_FLUTTER value: $LEAK_SCAN_FLUTTER (expected unset or 'skip')" >&2
        exit 1
        ;;
esac

P1="nost"
P2="avia"
PAT="${P1}${P2}"

FOUND=0

echo "== Scanning tracked file contents for old brand =="
if git grep -liE "$PAT" -- . > /tmp/leak-scan-contents.txt 2>/dev/null; then
    echo "Found references in tracked file contents:"
    cat /tmp/leak-scan-contents.txt
    FOUND=1
else
    echo "clean"
fi

echo "== Scanning tracked file names for old brand =="
if git ls-files | grep -iE "$PAT" > /tmp/leak-scan-filenames.txt; then
    echo "Found references in tracked file names:"
    cat /tmp/leak-scan-filenames.txt
    FOUND=1
else
    echo "clean"
fi

scan_dir() {
    local dir="$1"
    local skippable="${2:-false}"
    if [ -d "$dir" ]; then
        echo "== Scanning $dir =="
        if grep -rliE "$PAT" "$dir" 2>/dev/null | grep -q .; then
            echo "Found references in $dir:"
            grep -rliE "$PAT" "$dir" 2>/dev/null
            FOUND=1
        elif find "$dir" -iregex ".*${P1}${P2}.*" | grep -q .; then
            echo "Found file names in $dir:"
            find "$dir" -iregex ".*${P1}${P2}.*"
            FOUND=1
        else
            echo "clean"
        fi
    elif [ "$skippable" = "true" ] && [ "$LEAK_SCAN_FLUTTER" = "skip" ]; then
        echo "SKIPPED (LEAK_SCAN_FLUTTER=skip: no Flutter paths changed): $dir"
    else
        echo "LEAK SCAN FAILED: required build output missing: $dir (build it first; see CLAUDE.md)" >&2
        FOUND=1
    fi
}

scan_dir "dist"
scan_dir "space/dist"
scan_dir "flutter_app/build/web" "true"

APK="flutter_app/build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK" ]; then
    echo "== Scanning unzipped $APK =="
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT
    unzip -q -o "$APK" -d "$TMPDIR"
    if grep -rliE "$PAT" "$TMPDIR" 2>/dev/null | grep -q .; then
        echo "Found references inside APK:"
        grep -rliE "$PAT" "$TMPDIR" 2>/dev/null
        FOUND=1
    elif find "$TMPDIR" -iregex ".*${P1}${P2}.*" | grep -q .; then
        echo "Found file names inside APK:"
        find "$TMPDIR" -iregex ".*${P1}${P2}.*"
        FOUND=1
    else
        echo "clean"
    fi
    rm -rf "$TMPDIR"
    trap - EXIT
elif [ "$LEAK_SCAN_FLUTTER" = "skip" ]; then
    echo "SKIPPED (LEAK_SCAN_FLUTTER=skip: no Flutter paths changed): $APK"
else
    echo "LEAK SCAN FAILED: required build output missing: $APK (build it first; see CLAUDE.md)" >&2
    FOUND=1
fi

if [ "$FOUND" -ne 0 ]; then
    echo "LEAK SCAN FAILED: old brand references found above." >&2
    exit 1
fi

echo "LEAK SCAN PASSED: no old brand references found."
