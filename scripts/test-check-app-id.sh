#!/usr/bin/env bash
# TC-021 self-test for scripts/check-app-id.sh: the check must pass on the
# current tree and fail on each regression below (run in a scratch copy).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

IOS=flutter_app/ios
PBX=$IOS/Runner.xcodeproj/project.pbxproj
# A made-up team ID, built from parts so the real check does not flag this file.
FAKE_TEAM="ABCDE""12345"
MANIFEST=flutter_app/android/app/src/main/AndroidManifest.xml

fresh() {
  rm -rf "$TMP/repo"; mkdir -p "$TMP/repo"
  local f files=()
  for f in scripts/check-app-id.sh flutter_app/android/app/build.gradle \
      flutter_app/android/app/src/main/kotlin/com/zyndio/app/MainActivity.kt "$MANIFEST" \
      "$PBX" $IOS/Runner/Info.plist $IOS/Watch.xcconfig $IOS/add_watch_target.rb $IOS/Flutter/Team.xcconfig docs/APP_ID.md; do
    [[ -e "$ROOT/$f" ]] && files+=("$f")  # a missing file is the check's job to report
  done
  (cd "$ROOT" && tar cf - "${files[@]}") | tar xf - -C "$TMP/repo"
  mkdir -p "$TMP/repo/$IOS/Flutter" "$TMP/repo/docs"
}

expect() { # expect <pass|fail> <name> <pattern-in-output>
  local want="$1" name="$2" pat="$3" out rc=0
  git -C "$TMP/repo" init -q 2>/dev/null || true
  git -C "$TMP/repo" add -A
  out="$(bash "$TMP/repo/scripts/check-app-id.sh" 2>&1)" || rc=$?
  if [[ "$want" == pass && $rc -eq 0 ]] || [[ "$want" == fail && $rc -ne 0 && "$out" == *"$pat"* ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc)"; echo "$out" | sed 's/^/       /'; fail=1
  fi
}

fresh; expect pass "current tree passes" ""

fresh; sed -i "0,/CODE_SIGN_STYLE = Automatic;/s//CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = $FAKE_TEAM;/" "$TMP/repo/$PBX"
expect fail "team ID hard-coded in project.pbxproj" "hard-coded DEVELOPMENT_TEAM outside"

fresh; printf "  config.build_settings['DEVELOPMENT_TEAM'] = '%s'\n" "$FAKE_TEAM" >> "$TMP/repo/$IOS/add_watch_target.rb"
expect fail "team ID hard-coded in add_watch_target.rb" "hard-coded DEVELOPMENT_TEAM outside"

fresh; echo "DEVELOPMENT_TEAM = $FAKE_TEAM" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "team ID hard-coded in Watch.xcconfig" "hard-coded DEVELOPMENT_TEAM outside"

fresh; echo "Old team: FF6X""228VNT" >> "$TMP/repo/docs/APP_ID.md"
expect fail "old placeholder team ID back in a doc" "old placeholder team ID"

fresh; echo 'DEVELOPMENT_TEAM = not-an-id' > "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect fail "malformed team ID in Team.xcconfig" "must set DEVELOPMENT_TEAM exactly once"

fresh; printf 'DEVELOPMENT_TEAM =\nDEVELOPMENT_TEAM = %s\n' "$FAKE_TEAM" > "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect fail "team ID set twice in Team.xcconfig" "must set DEVELOPMENT_TEAM exactly once"

fresh; echo "DEVELOPMENT_TEAM = $FAKE_TEAM" > "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect pass "a real 10-character team ID in Team.xcconfig passes" ""

fresh; rm "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect fail "Team.xcconfig missing" "Team.xcconfig is missing"

fresh; sed -i '/Team.xcconfig/d' "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "Watch.xcconfig no longer includes Team.xcconfig" "must #include"

fresh; sed -i 's/com\.zyndio\.app\.watchkitapp/com.zyndio.app.watchapp/' "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "Watch.xcconfig drifts to watchapp" "Watch.xcconfig PRODUCT_BUNDLE_IDENTIFIER must be com.zyndio.app.watchkitapp"

fresh; sed -i "s/^bundle_id = '.*'/bundle_id = 'com.zyndio.app.watch'/" "$TMP/repo/$IOS/add_watch_target.rb"
expect fail "add_watch_target.rb drifts from Watch.xcconfig" "add_watch_target.rb bundle_id must be com.zyndio.app.watchkitapp"

fresh; sed -i '/<string>com\.zyndio\.health<\/string>/d' "$TMP/repo/$IOS/Runner/Info.plist"
expect fail "iOS drops com.zyndio.health" "same deep-link schemes"

fresh; sed -i '0,/android:scheme="zyndiohealth"/s//android:scheme="zyndio-extra"/' "$TMP/repo/$MANIFEST"
expect fail "Android adds a scheme iOS lacks" "same deep-link schemes"

# --- TC-021 item 15: Xcode's TargetAttributes DevelopmentTeam and SDK-conditional settings
# Built from parts so the real check does not flag this file.
DT_ATTR="Development""Team"
DT_IOS="DEVELOPMENT_TEAM""[sdk=iphoneos*]"
DT_WATCH="DEVELOPMENT_TEAM""[sdk=watchos*]"
fresh; sed -i "0,/CreatedOnToolsVersion = 16.4.1;/s//CreatedOnToolsVersion = 16.4.1;\n\t\t\t\t\t\t$DT_ATTR = $FAKE_TEAM;/" "$TMP/repo/$PBX"
expect fail "DevelopmentTeam in project.pbxproj TargetAttributes" "hard-coded DevelopmentTeam"

fresh; sed -i "0,/CODE_SIGN_STYLE = Automatic;/s//CODE_SIGN_STYLE = Automatic;\n\t\t\t\t\"$DT_IOS\" = $FAKE_TEAM;/" "$TMP/repo/$PBX"
expect fail "SDK-conditional DEVELOPMENT_TEAM in project.pbxproj" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_WATCH = $FAKE_TEAM" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "SDK-conditional DEVELOPMENT_TEAM in Watch.xcconfig" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_IOS = $FAKE_TEAM" >> "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect fail "SDK-conditional DEVELOPMENT_TEAM inside Team.xcconfig" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_IOS =" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "empty SDK-conditional DEVELOPMENT_TEAM (overrides the single setting)" "SDK-conditional DEVELOPMENT_TEAM"

# --- TC-021 item 22: multi-condition forms, any order or combination of bracket conditions.
DT_MULTI="DEVELOPMENT_TEAM""[config=Release][sdk=iphoneos*]"
DT_MULTI_REV="DEVELOPMENT_TEAM""[sdk=iphoneos*][config=Release]"
DT_MULTI3="DEVELOPMENT_TEAM""[config=Debug][sdk=watchos*][arch=arm64]"
fresh; sed -i "0,/CODE_SIGN_STYLE = Automatic;/s//CODE_SIGN_STYLE = Automatic;\n\t\t\t\t\"$DT_MULTI\" = $FAKE_TEAM;/" "$TMP/repo/$PBX"
expect fail "multi-condition [config][sdk] DEVELOPMENT_TEAM in project.pbxproj" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_MULTI = $FAKE_TEAM" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "multi-condition [config][sdk] DEVELOPMENT_TEAM in Watch.xcconfig" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_MULTI_REV = $FAKE_TEAM" >> "$TMP/repo/$IOS/Flutter/Team.xcconfig"
expect fail "multi-condition [sdk][config] (reversed order) inside Team.xcconfig" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_MULTI3 = $FAKE_TEAM" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "three bracket conditions [config][sdk][arch]" "SDK-conditional DEVELOPMENT_TEAM"

fresh; echo "$DT_MULTI =" >> "$TMP/repo/$IOS/Watch.xcconfig"
expect fail "empty multi-condition DEVELOPMENT_TEAM (overrides the single setting)" "SDK-conditional DEVELOPMENT_TEAM"

fresh; printf "  config.build_settings['%s'] = '%s'\n" "$DT_MULTI" "$FAKE_TEAM" >> "$TMP/repo/$IOS/add_watch_target.rb"
expect fail "multi-condition DEVELOPMENT_TEAM in add_watch_target.rb build_settings" "SDK-conditional DEVELOPMENT_TEAM"

exit "$fail"
