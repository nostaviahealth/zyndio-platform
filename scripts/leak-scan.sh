#!/usr/bin/env bash
# Scans for leftover references to the old product brand name (assembled from
# parts so this script itself never contains the literal word) across:
#   - tracked file contents
#   - tracked file names
#   - web build output (dist/, space/dist/)
#   - Flutter web build output (flutter_app/build/web)
#   - an unzipped Flutter debug APK (flutter_app/build/app/outputs/flutter-apk/app-debug.apk)
# Exits 1 on any hit.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

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
    fi
}

scan_dir "dist"
scan_dir "space/dist"
scan_dir "flutter_app/build/web"

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
fi

if [ "$FOUND" -ne 0 ]; then
    echo "LEAK SCAN FAILED: old brand references found above." >&2
    exit 1
fi

echo "LEAK SCAN PASSED: no old brand references found."
