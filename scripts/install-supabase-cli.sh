#!/usr/bin/env bash
# Install one pinned Supabase CLI release. The theme and database jobs keep
# the same 2.122.0 binary the workflow used to request from setup-cli. A 504
# from the release host is retried; the CLI is not skipped.
set -euo pipefail

version="${1:?supabase cli version, for example 2.122.0}"
url="https://github.com/supabase/cli/releases/download/v${version}/supabase_linux_amd64.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok=0
for attempt in 1 2 3 4 5; do
  if curl -sSfL --retry 5 --retry-all-errors --retry-delay 3 -o "$tmp/supabase.tar.gz" "$url"; then
    ok=1
    break
  fi
  echo "supabase cli download attempt ${attempt} failed"
  sleep $((attempt * 5))
done
test "$ok" = 1

tar -xzf "$tmp/supabase.tar.gz" -C "$tmp"
install -m 0755 "$tmp/supabase" /usr/local/bin/supabase
got="$(supabase --version | awk '{print $NF}')"
test "$got" = "$version"
echo "supabase cli ${got}"
