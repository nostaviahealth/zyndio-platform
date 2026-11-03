#!/usr/bin/env bash
# TC-040 LOCAL-ONLY: timing check for clinic-staff signed links on lab-report
# files at 10,000 fictional patients per clinic (budget: every sign < 5 ms).
# The bench runs in one rolled-back transaction, so it leaves nothing behind.
# Never run against a remote/production database.
#
# Uses $DB_URL if set, else `supabase status -o env` of the local stack.
# Exit 1 if the budget line is not PASS.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${DB_URL:-}" ]; then
  eval "$(supabase status -o env)"
fi
if [ -z "${DB_URL:-}" ]; then
  echo "DB_URL not set and not found from 'supabase status' - is the local stack running?" >&2
  exit 1
fi
case "$DB_URL" in
  *@127.0.0.1:*|*@localhost:*) ;;
  *) echo "refusing: DB_URL is not a local database" >&2; exit 1 ;;
esac
out="$(psql "$DB_URL" -X -q -f docs/perf/tc-040/sign_bench.sql 2>&1)"
echo "$out"
echo "$out" | grep -q 'PASS (every sign < 5 ms)'
