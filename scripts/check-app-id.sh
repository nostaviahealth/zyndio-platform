#!/usr/bin/env bash
# TC-020: pin the store app ID. Google Play never lets a package name change
# after the first upload, so any drift from the registered ID must fail CI.
#   Android applicationId + namespace     == com.zyndio.app
#   MainActivity package + folder         == com.zyndio.app
#   iOS PRODUCT_BUNDLE_IDENTIFIER (all)   == com.zyndio.app or com.zyndio.app.<Suffix>
#   iOS Runner Info.plist CFBundleIdentifier follows the build setting
#   Watch xcconfig / add_watch_target.rb  == com.zyndio.app.watchkitapp (TC-021)
#   The old placeholder ID appears nowhere in tracked files.
# TC-021 additions:
#   DEVELOPMENT_TEAM is set in ONE place, flutter_app/ios/Flutter/Team.xcconfig
#   (empty or a 10-character Apple team ID); any other hard-coded team ID in a
#   tracked file fails, and the two old placeholder team IDs appear nowhere.
#   Item 15: also fails on Xcode's TargetAttributes `DevelopmentTeam = <ID>` in
#   project.pbxproj and on any SDK-conditional DEVELOPMENT_TEAM[sdk=...] setting.
#   iOS CFBundleURLSchemes and the Android BROWSABLE deep-link schemes are the
#   same set (SDK callback schemes for Google / Facebook sign-in excluded).
# packages/platform_wearables keeps its own ID (com.zyndio.wearables).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

APP_ID="com.zyndio.app"
WATCH_ID="com.zyndio.app.watchkitapp"
# Built from parts so this script does not match its own search.
OLD_ID="com.zyndio.""patient"
fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
ok() { echo "OK: $*"; }

GRADLE="flutter_app/android/app/build.gradle"
APP_ID_RE='^com\.zyndio\.app$'
SUFFIX_RE='^com\.zyndio\.app(\.[A-Za-z0-9-]+)?$'

app_ids=$(sed -nE 's/^[[:space:]]*applicationId[[:space:]=]+"([^"]+)".*/\1/p' "$GRADLE")
if [[ "$(wc -l <<<"$app_ids")" -eq 1 && "$app_ids" =~ $APP_ID_RE ]]; then
  ok "Android applicationId = $app_ids"
else
  err "Android applicationId in $GRADLE must be exactly $APP_ID (got: ${app_ids:-missing})"
fi

namespaces=$(sed -nE 's/^[[:space:]]*namespace[[:space:]=]+"([^"]+)".*/\1/p' "$GRADLE")
if [[ "$(wc -l <<<"$namespaces")" -eq 1 && "$namespaces" =~ $APP_ID_RE ]]; then
  ok "Android namespace = $namespaces"
else
  err "Android namespace in $GRADLE must be exactly $APP_ID (got: ${namespaces:-missing})"
fi

MAIN_KT="flutter_app/android/app/src/main/kotlin/com/zyndio/app/MainActivity.kt"
if [[ -f "$MAIN_KT" ]] && grep -qx "package $APP_ID" "$MAIN_KT"; then
  ok "MainActivity.kt is in package $APP_ID"
else
  err "$MAIN_KT must exist and declare 'package $APP_ID'"
fi

PBX="flutter_app/ios/Runner.xcodeproj/project.pbxproj"
bundle_ids=$(sed -nE 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;.*/\1/p' "$PBX")
if [[ -z "$bundle_ids" ]]; then
  err "no PRODUCT_BUNDLE_IDENTIFIER found in $PBX"
fi
# The Runner app target itself (app, all three configs) must be the bare ID.
runner_count=$(grep -cxF "$APP_ID" <<<"$bundle_ids" || true)
if [[ "$runner_count" -ge 3 ]]; then
  ok "iOS Runner bundle ID = $APP_ID ($runner_count configs)"
else
  err "iOS Runner bundle ID must be $APP_ID in Debug/Release/Profile (found $runner_count)"
fi
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  if [[ "$id" =~ $SUFFIX_RE ]]; then
    ok "iOS bundle ID $id"
  else
    err "iOS bundle ID '$id' in $PBX is not $APP_ID or $APP_ID.<suffix>"
  fi
done <<<"$bundle_ids"

PLIST="flutter_app/ios/Runner/Info.plist"
plist_id=$(awk '/<key>CFBundleIdentifier<\/key>/{getline; gsub(/^[[:space:]]*<string>|<\/string>[[:space:]]*$/, ""); print; exit}' "$PLIST")
if [[ "$plist_id" == '$(PRODUCT_BUNDLE_IDENTIFIER)' || "$plist_id" == "$APP_ID" ]]; then
  ok "Runner Info.plist CFBundleIdentifier = $plist_id"
else
  err "Runner Info.plist CFBundleIdentifier must be \$(PRODUCT_BUNDLE_IDENTIFIER) or $APP_ID (got: ${plist_id:-missing})"
fi

WATCH_CFG="flutter_app/ios/Watch.xcconfig"
watch_id=$(sed -nE 's/^PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/p' "$WATCH_CFG")
companion=$(sed -nE 's/^INFOPLIST_KEY_WKCompanionAppBundleIdentifier[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/p' "$WATCH_CFG")
if [[ "$watch_id" == "$WATCH_ID" ]]; then
  ok "Watch bundle ID = $watch_id"
else
  err "Watch.xcconfig PRODUCT_BUNDLE_IDENTIFIER must be $WATCH_ID (got: ${watch_id:-missing})"
fi
if [[ "$companion" == "$APP_ID" ]]; then
  ok "Watch companion app = $companion"
else
  err "Watch.xcconfig WKCompanionAppBundleIdentifier must be $APP_ID (got: ${companion:-missing})"
fi

WATCH_RB="flutter_app/ios/add_watch_target.rb"
rb_id=$(sed -nE "s/^bundle_id = '([^']+)'.*/\1/p" "$WATCH_RB")
if [[ "$rb_id" == "$WATCH_ID" ]]; then
  ok "add_watch_target.rb bundle_id = $rb_id"
else
  err "add_watch_target.rb bundle_id must be $WATCH_ID, the same as Watch.xcconfig (got: ${rb_id:-missing})"
fi

# --- TC-021 item 3: Apple team ID set in one place, never hard-coded --------
TEAM_CFG="flutter_app/ios/Flutter/Team.xcconfig"
if [[ -f "$TEAM_CFG" ]]; then
  team_lines=$(grep -cE '^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=' "$TEAM_CFG" || true)
  team_val=$(sed -nE 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*([^[:space:]]*).*/\1/p' "$TEAM_CFG")
  if [[ "$team_lines" -eq 1 && ( -z "$team_val" || "$team_val" =~ ^[A-Z0-9]{10}$ ) ]]; then
    ok "DEVELOPMENT_TEAM set once in $TEAM_CFG (${team_val:-empty until the Apple team ID arrives})"
  else
    err "$TEAM_CFG must set DEVELOPMENT_TEAM exactly once, empty or a 10-character team ID (got $team_lines line(s): '${team_val}')"
  fi
else
  err "$TEAM_CFG is missing (the single DEVELOPMENT_TEAM setting)"
fi
if grep -qF 'Team.xcconfig' "$PBX"; then
  ok "project.pbxproj references Team.xcconfig"
else
  err "$PBX does not reference Team.xcconfig (targets would not get DEVELOPMENT_TEAM)"
fi
if grep -qE '^#include "Flutter/Team.xcconfig"' "$WATCH_CFG"; then
  ok "Watch.xcconfig includes Team.xcconfig"
else
  err "$WATCH_CFG must #include \"Flutter/Team.xcconfig\""
fi
# Any DEVELOPMENT_TEAM assignment with a team-ID-shaped value outside Team.xcconfig.
team_hits=$(git grep -nE "DEVELOPMENT_TEAM['\"]?\]?[[:space:]]*=[[:space:]]*['\"]?[A-Z0-9]{10}\b" -- . ":!$TEAM_CFG" 2>/dev/null || true)
if [[ -n "$team_hits" ]]; then
  err "hard-coded DEVELOPMENT_TEAM outside $TEAM_CFG:"
  echo "$team_hits" >&2
else
  ok "no hard-coded DEVELOPMENT_TEAM outside $TEAM_CFG"
fi
# TC-021 item 15: Xcode also stores the team as TargetAttributes "DevelopmentTeam = <ID>;"
# in project.pbxproj (set when a team is picked in the Signing tab).
attr_hits=$(git grep -nE "DevelopmentTeam[[:space:]]*=[[:space:]]*['\"]?[A-Z0-9]{10}\b" -- . 2>/dev/null || true)
if [[ -n "$attr_hits" ]]; then
  err "hard-coded DevelopmentTeam (TargetAttributes) in tracked files; the team comes only from $TEAM_CFG:"
  echo "$attr_hits" >&2
else
  ok "no hard-coded DevelopmentTeam (TargetAttributes)"
fi
# SDK-conditional settings (DEVELOPMENT_TEAM[sdk=...], [config=...], [arch=...]) override the
# single setting even when empty, so none are allowed anywhere, Team.xcconfig included.
cond_hits=$(git grep -nE "DEVELOPMENT_TEAM\[[^]]*\]['\"]?[[:space:]]*=" -- . 2>/dev/null || true)
if [[ -n "$cond_hits" ]]; then
  err "SDK-conditional DEVELOPMENT_TEAM[...] setting found; set DEVELOPMENT_TEAM only once, unconditionally, in $TEAM_CFG:"
  echo "$cond_hits" >&2
else
  ok "no SDK-conditional DEVELOPMENT_TEAM[...] settings"
fi
# The two old placeholder team IDs, built from parts so this script does not match itself.
OLD_TEAMS=("FF6X""228VNT" "3QW98""F397X")
for t in "${OLD_TEAMS[@]}"; do
  if old_team_hits=$(git grep -n -F "$t" -- . 2>/dev/null) && [[ -n "$old_team_hits" ]]; then
    err "old placeholder team ID still present in tracked files:"
    echo "$old_team_hits" >&2
  fi
done

# --- TC-021 item 2: same deep-link schemes on iOS and Android ----------------
MANIFEST="flutter_app/android/app/src/main/AndroidManifest.xml"
scheme_out=$(python3 - "$MANIFEST" "$PLIST" <<'PY'
import plistlib, re, sys
import xml.etree.ElementTree as ET
A = '{http://schemas.android.com/apk/res/android}'
SDK = re.compile(r'^(com\.googleusercontent\.apps\..+|fb[0-9]+)$')
root = ET.parse(sys.argv[1]).getroot()
android = set()
app = root.find('application')
for comp in list(app.iter('activity')) + list(app.iter('activity-alias')):
    for f in comp.iter('intent-filter'):
        cats = {c.get(A + 'name') for c in f.iter('category')}
        if 'android.intent.category.BROWSABLE' not in cats:
            continue
        for d in f.iter('data'):
            s = d.get(A + 'scheme')
            if s and s not in ('http', 'https'):
                android.add(s)
with open(sys.argv[2], 'rb') as fh:
    pl = plistlib.load(fh)
ios = {s for t in pl.get('CFBundleURLTypes', []) for s in t.get('CFBundleURLSchemes', []) if not SDK.match(s)}
print('android=' + ','.join(sorted(android)))
print('ios=' + ','.join(sorted(ios)))
sys.exit(0 if android == ios and android else 3)
PY
) && scheme_rc=0 || scheme_rc=$?
if [[ "$scheme_rc" -eq 0 ]]; then
  ok "deep-link schemes match on iOS and Android ($(sed -n 's/^android=//p' <<<"$scheme_out"))"
else
  err "iOS and Android must declare the same deep-link schemes ($(tr '\n' ' ' <<<"$scheme_out"))"
fi

if old_hits=$(git grep -n -F "$OLD_ID" -- . 2>/dev/null) && [[ -n "$old_hits" ]]; then
  err "old app ID still present in tracked files:"
  echo "$old_hits" >&2
else
  ok "old app ID appears in no tracked file"
fi
OLD_KT_DIR="kotlin/com/zyndio/""patient/"
if git ls-files | grep -qF "$OLD_KT_DIR"; then
  err "old Kotlin package folder $OLD_KT_DIR is still tracked"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "App ID pin FAILED (expected $APP_ID)." >&2
  exit 1
fi
echo "App ID pin passed: $APP_ID"
