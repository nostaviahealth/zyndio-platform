#!/usr/bin/env bash
# Clara H-M1 / TC-012: patient signup is invite-closed + Edge-only.
# Fail if any [auth.external.*] provider is enabled, or if [auth]
# enable_signup is not false.
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
CFG="$ROOT/supabase/config.toml"

if [[ ! -f "$CFG" ]]; then
  echo "FAIL: missing $CFG" >&2
  exit 1
fi

# [auth] enable_signup must be false (not the [auth.email] one).
auth_signup=$(awk '
  /^\[auth\]/ { in_auth=1; next }
  /^\[/ { in_auth=0 }
  in_auth && /^enable_signup[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $0)
    split($0, a, "=")
    print a[2]
    exit
  }
' "$CFG")

if [[ "$auth_signup" != "false" ]]; then
  echo "FAIL: [auth] enable_signup must be false (got: ${auth_signup:-missing})" >&2
  exit 1
fi
echo "OK: [auth] enable_signup = false"

# Any [auth.external.*] block with enabled = true fails.
enabled_externals=$(awk '
  /^\[auth\.external\./ { section=$0; in_ext=1; next }
  /^\[/ { in_ext=0 }
  in_ext && /^enabled[[:space:]]*=[[:space:]]*true/ {
    print section
  }
' "$CFG")

if [[ -n "$enabled_externals" ]]; then
  echo "FAIL: external auth provider(s) enabled:" >&2
  echo "$enabled_externals" >&2
  exit 1
fi
echo "OK: no [auth.external.*] provider enabled=true"
