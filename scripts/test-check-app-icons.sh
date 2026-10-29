#!/usr/bin/env bash
# TC-023 self-test for scripts/check-app-icons.sh: the check must pass on the
# current tree and fail on each regression below (run in a scratch copy).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

fresh() {
  rm -rf "$TMP/repo"; mkdir -p "$TMP/repo"
  (cd "$ROOT" && tar cf - scripts/check-app-icons.sh scripts/app-icons.sha256 index.html public \
     store-assets flutter_app/pubspec.yaml flutter_app/pubspec.lock \
     flutter_app/android/app/src/main/res flutter_app/ios/Runner/Assets.xcassets) | tar xf - -C "$TMP/repo"
  git -C "$TMP/repo" init -q
}

expect() { # expect <pass|fail> <name> <pattern-in-output>
  local want="$1" name="$2" pat="$3" out rc=0
  out="$(bash "$TMP/repo/scripts/check-app-icons.sh" 2>&1)" || rc=$?
  if [[ "$want" == pass && $rc -eq 0 ]] || [[ "$want" == fail && $rc -ne 0 && "$out" == *"$pat"* ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc)"; echo "$out" | sed 's/^/       /'; fail=1
  fi
}

RES=flutter_app/android/app/src/main/res
XC=flutter_app/ios/Runner/Assets.xcassets

fresh; expect pass "current tree passes" ""

fresh; printf '\nflutter_launcher_icons:\n  android: true\n  ios: true\n' >> "$TMP/repo/flutter_app/pubspec.yaml"
expect fail "generator config back in pubspec.yaml" "flutter_launcher_icons generator is back"

fresh; printf 'flutter_launcher_icons:\n  android: true\n' > "$TMP/repo/flutter_app/flutter_launcher_icons.yaml"
expect fail "standalone flutter_launcher_icons.yaml" "flutter_launcher_icons generator is back"

fresh; python3 - "$TMP/repo/$XC/AppIcon.appiconset/Icon-App-1024x1024@1x.png" <<'PY'
import struct, sys, zlib
w = h = 1024
raw = b''.join(b'\x00' + b'\xff\xff\xff\x80' * w for _ in range(h))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
    + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
open(sys.argv[1], 'wb').write(png)
PY
expect fail "RGBA iOS 1024 icon" "has an alpha channel"

fresh; mkdir -p "$TMP/repo/$XC/AppIcon-single-size.appiconset"; echo '{"images":[]}' > "$TMP/repo/$XC/AppIcon-single-size.appiconset/Contents.json"
expect fail "two iOS icon sets" "exactly one app icon set"

fresh; sed -i 's|#FFFFFF|#2C5CF2|' "$TMP/repo/$RES/values/colors.xml"
expect fail "old #2C5CF2 launcher background" "ic_launcher_background must be #FFFFFF"

fresh; cat > "$TMP/repo/$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground><inset android:drawable="@drawable/ic_launcher_foreground" android:inset="16%" /></foreground>
</adaptive-icon>
XML
expect fail "old 16% inset ic_launcher.xml" "uses an inset"

fresh; cp "$TMP/repo/$RES/mipmap-mdpi/ic_launcher_foreground.png" "$TMP/repo/$RES/drawable-mdpi/ic_launcher_foreground.png"
expect fail "old drawable foreground back" "old drawable foregrounds are back"

fresh; printf 'x' >> "$TMP/repo/public/favicon-32.png"
expect fail "icon differs from handoff hash" "does not match Ava's handoff"

fresh; rm "$TMP/repo/public/apple-touch-icon.png"
expect fail "head link target missing" "does not exist in public/"

fresh; sed -i 's|<link rel="manifest" href="/site.webmanifest">||' "$TMP/repo/index.html"
expect fail "head manifest line removed" "missing head lines"

fresh; sed -i 's|/maskable-512.png|/maskable-1024.png|' "$TMP/repo/public/site.webmanifest"
expect fail "manifest icon missing" "site.webmanifest icon /maskable-1024.png missing"

fresh; touch "$TMP/repo/favicon.png"
expect fail "root favicon.png back" "old root favicon.png is back"

exit $fail
