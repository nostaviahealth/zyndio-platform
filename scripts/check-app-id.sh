#!/usr/bin/env bash
# TC-020: pin the store app ID. Google Play never lets a package name change
# after the first upload, so any drift from the registered ID must fail CI.
#   Android applicationId + namespace     == com.zyndio.app
#   MainActivity package + folder         == com.zyndio.app
#   iOS PRODUCT_BUNDLE_IDENTIFIER (all)   == com.zyndio.app or com.zyndio.app.<Suffix>
#   iOS Runner Info.plist CFBundleIdentifier follows the build setting
#   Watch xcconfig / add_watch_target.rb  == com.zyndio.app.<suffix>
#   The old placeholder ID appears nowhere in tracked files.
# packages/platform_wearables keeps its own ID (com.zyndio.wearables).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

APP_ID="com.zyndio.app"
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
if [[ "$watch_id" =~ $SUFFIX_RE && "$watch_id" != "$APP_ID" ]]; then
  ok "Watch bundle ID = $watch_id"
else
  err "Watch.xcconfig PRODUCT_BUNDLE_IDENTIFIER must be $APP_ID.<suffix> (got: ${watch_id:-missing})"
fi
if [[ "$companion" == "$APP_ID" ]]; then
  ok "Watch companion app = $companion"
else
  err "Watch.xcconfig WKCompanionAppBundleIdentifier must be $APP_ID (got: ${companion:-missing})"
fi

WATCH_RB="flutter_app/ios/add_watch_target.rb"
rb_id=$(sed -nE "s/^bundle_id = '([^']+)'.*/\1/p" "$WATCH_RB")
if [[ "$rb_id" =~ $SUFFIX_RE && "$rb_id" != "$APP_ID" ]]; then
  ok "add_watch_target.rb bundle_id = $rb_id"
else
  err "add_watch_target.rb bundle_id must be $APP_ID.<suffix> (got: ${rb_id:-missing})"
fi

if old_hits=$(git grep -n -F "$OLD_ID" -- . 2>/dev/null) && [[ -n "$old_hits" ]]; then
  err "old app ID still present in tracked files:"
  echo "$old_hits" >&2
else
  ok "old app ID appears in no tracked file"
fi
if git ls-files | grep -q 'kotlin/com/zyndio/patient/'; then
  err "old Kotlin package folder kotlin/com/zyndio/patient/ is still tracked"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "App ID pin FAILED (expected $APP_ID)." >&2
  exit 1
fi
echo "App ID pin passed: $APP_ID"
