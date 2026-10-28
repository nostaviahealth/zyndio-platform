#!/usr/bin/env bash
# Builds the admin preview bundle against the local Supabase stack's anon
# key (VITE_SUPABASE_URL/VITE_SUPABASE_ANON_KEY from `supabase status -o env`,
# exported into this process only - never written to a file) and runs
# scripts/demo_screenshots_admin.py against it.
#
# Assumes `supabase start` has already been run. Local Supabase only.
set -euo pipefail

cd "$(dirname "$0")/.."

status_env="$(supabase status -o env)"
eval "$status_env"

export VITE_SUPABASE_URL="$API_URL"
export VITE_SUPABASE_ANON_KEY="$ANON_KEY"

npm run build:preview
python3 scripts/demo_screenshots_admin.py "$@"
