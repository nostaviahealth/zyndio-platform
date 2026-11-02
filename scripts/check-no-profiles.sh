#!/usr/bin/env bash
# TC-026 guard: fail if any RUNTIME code still references the removed `profiles`
# table. The old flat `profiles` table is being retired; every read/write now
# goes to the real patient/user tables (patient_accounts, patient_profiles,
# patients, org_members, ...). This stops a `.from('profiles')` / realtime
# `table: 'profiles'` / `FROM profiles` from sneaking back into runtime code.
#
# Scanned (tracked files only, via git grep):
#   flutter_app/lib, pages, components, contexts, lib, src,
#   supabase/functions, scripts
# Excluded:
#   - this script itself
#   - */migrations/* (SQL migrations are the schema history, incl. the eventual
#     drop; they legitimately name the table)
#   - supabase/_legacy/* (historical, not runtime)
#   - test/spec files (they *assert* the absence of `profiles`)
#
# A match means real table use, not prose: we only flag a quoted table name
# (`'profiles'` / `"profiles"`, the Supabase-JS/Dart form) or a SQL
# FROM/INTO/UPDATE/JOIN/TABLE on `profiles`. Comments that mention the word,
# the `patient_profiles` table, and the `profiles:` key in the legacy generated
# type stub are intentionally NOT matched.
#
# Exits 1 on any hit, 0 when clean.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Quoted table reference: 'profiles' or "profiles" (a quote immediately on each
# side, so 'patient_profiles' / 'patient_accounts' do NOT match).
QUOTED="['\"]profiles['\"]"
# SQL object reference: FROM/INTO/UPDATE/JOIN/TABLE [public.]profiles, where
# profiles is NOT a prefix of a longer identifier (so patient_profiles is safe).
SQL="(from|into|update|join|table)[[:space:]]+(public\.)?profiles([^_a-z0-9]|$)"

PATHS=(
    flutter_app/lib
    pages
    components
    contexts
    lib
    src
    supabase/functions
    scripts
)

EXCLUDES=(
    ':!scripts/check-no-profiles.sh'
    ':!**/migrations/**'
    ':!supabase/_legacy/**'
    ':!**/*test*'
    ':!**/*spec*'
)

echo "== Scanning runtime code for references to the removed 'profiles' table =="
if git grep -nIiE -e "$QUOTED" -e "$SQL" -- "${PATHS[@]}" "${EXCLUDES[@]}" > /tmp/check-no-profiles.txt 2>/dev/null; then
    echo "CHECK-NO-PROFILES FAILED: runtime code still references the 'profiles' table:" >&2
    cat /tmp/check-no-profiles.txt >&2
    echo >&2
    echo "Move these reads/writes to the real tables (patient_accounts / patient_profiles / etc.)." >&2
    exit 1
fi

echo "CHECK-NO-PROFILES PASSED: no runtime references to the 'profiles' table."
