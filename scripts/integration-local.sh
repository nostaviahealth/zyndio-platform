#!/usr/bin/env bash
# Runs tests/integration/*.test.ts against a local Supabase stack.
#
# - Starts `supabase functions serve` in the background (admin-actions.test.ts
#   and recovery-codes.test.ts need the Edge Functions).
# - Exports SUPABASE_URL/SUPABASE_ANON_KEY/SUPABASE_SERVICE_ROLE_KEY/
#   SUPABASE_FUNCTIONS_URL from `supabase status -o env` into this process
#   only - never written to a file.
# - Always stops `supabase functions serve` on exit, even on failure.
# - TC-014: waits until an edge function answers with a non-503 status
#   (warm / ready). A connection error or sustained 503 times out the run;
#   individual test assertions are never retried.
#
# Assumes `supabase start` has already been run. Local Supabase only.
set -euo pipefail

cd "$(dirname "$0")/.."

FN_SERVE_PID_FILE=/tmp/zyndio-tc005-fn-serve.pid

cleanup() {
  if [ -f "$FN_SERVE_PID_FILE" ]; then
    kill "$(cat "$FN_SERVE_PID_FILE")" >/dev/null 2>&1 || true
    rm -f "$FN_SERVE_PID_FILE"
  fi
}
trap cleanup EXIT

status_env="$(supabase status -o env)"
eval "$status_env"

export SUPABASE_URL="$API_URL"
export SUPABASE_ANON_KEY="$ANON_KEY"
export SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"
export SUPABASE_FUNCTIONS_URL="${FUNCTIONS_URL:-${API_URL}/functions/v1}"

nohup supabase functions serve --no-verify-jwt >/tmp/tc005-functions-serve.log 2>&1 &
echo $! > "$FN_SERVE_PID_FILE"

# Poll via node's built-in fetch (never curl) until invite-user answers with
# anything other than 503. Connection refused / network errors keep polling.
# Clear timeout → fail the run (do not start tests against a cold serve).
node -e '
  const url = process.env.SUPABASE_FUNCTIONS_URL + "/invite-user";
  const deadline = Date.now() + 60_000;
  (async () => {
    while (Date.now() < deadline) {
      try {
        const res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: "{}",
        });
        if (res.status !== 503) {
          process.exit(0);
        }
      } catch {
        // not listening yet
      }
      await new Promise((r) => setTimeout(r, 500));
    }
    console.error("integration-local: edge functions still returning 503 (or unreachable) after 60s");
    process.exit(1);
  })();
'

npm run test:integration
