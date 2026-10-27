#!/usr/bin/env bash
# TC-015 LOCAL-ONLY: load the 500-patient perf dataset into the running local
# Supabase stack for roster / trend query-plan evidence. Idempotent - safe to
# re-run. Never run against a remote/production database (the seed is fictional
# demo data and is not a migration).
#
# Assumes `supabase start` has already been run. Reads DB_URL from
# `supabase status -o env` so no credentials are hard-coded here.
set -euo pipefail

cd "$(dirname "$0")/.."

status_env="$(supabase status -o env)"
eval "$status_env"

if [ -z "${DB_URL:-}" ]; then
  echo "DB_URL not found from 'supabase status' - is the local stack running?" >&2
  exit 1
fi

echo "Seeding 500 perf patients into the local stack..."
psql "$DB_URL" -v ON_ERROR_STOP=1 -q -f supabase/seed/perf_500_patients.sql
echo "Done. Perf org: 0000f015-0000-0000-0000-00000000000a (physician 0000f015-0000-0000-0000-0000000a0002)."
