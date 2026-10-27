#!/usr/bin/env bash
# Runs tests/integration/*.test.ts against a local Supabase stack.
#
# - Starts `supabase functions serve` in the background (admin-actions.test.ts
#   and recovery-codes.test.ts need the Edge Functions).
# - Exports SUPABASE_URL/SUPABASE_ANON_KEY/SUPABASE_SERVICE_ROLE_KEY/
#   SUPABASE_FUNCTIONS_URL from `supabase status -o env` into this process
#   only - never written to a durable file. A temp env-file is passed to
#   `functions serve` so Deno sees JWT_SECRET (HS256 service_role) and
#   SUPABASE_URL (ES256 JWKS for user access tokens) - required by TC-011
#   process-outbox signature verify.
# - Always stops `supabase functions serve` on exit, even on failure.
#
# Assumes `supabase start` has already been run. Local Supabase only.
set -euo pipefail

cd "$(dirname "$0")/.."

FN_SERVE_PID_FILE=/tmp/zyndio-tc005-fn-serve.pid
FN_ENV_FILE=/tmp/zyndio-tc005-fn-serve.env

cleanup() {
  if [ -f "$FN_SERVE_PID_FILE" ]; then
    kill "$(cat "$FN_SERVE_PID_FILE")" >/dev/null 2>&1 || true
    rm -f "$FN_SERVE_PID_FILE"
  fi
  rm -f "$FN_ENV_FILE"
}
trap cleanup EXIT

status_env="$(supabase status -o env)"
eval "$status_env"

export SUPABASE_URL="$API_URL"
export SUPABASE_ANON_KEY="$ANON_KEY"
export SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"
export SUPABASE_FUNCTIONS_URL="${FUNCTIONS_URL:-${API_URL}/functions/v1}"

# JWT_SECRET is present in `supabase status -o env` for local stacks; without
# it process-outbox cannot verify the legacy HS256 service_role key.
umask 077
cat > "$FN_ENV_FILE" <<ENV
JWT_SECRET=${JWT_SECRET}
SUPABASE_JWT_SECRET=${JWT_SECRET}
SUPABASE_URL=${API_URL}
API_URL=${API_URL}
ENV

nohup supabase functions serve --no-verify-jwt --env-file "$FN_ENV_FILE" >/tmp/tc005-functions-serve.log 2>&1 &
echo $! > "$FN_SERVE_PID_FILE"

# Poll via node's built-in fetch (never curl) until functions serve is up.
node -e '
  const url = process.env.SUPABASE_FUNCTIONS_URL + "/invite-user";
  (async () => {
    for (let i = 0; i < 30; i++) {
      try {
        await fetch(url, { method: "POST" });
        return;
      } catch {
        await new Promise((r) => setTimeout(r, 1000));
      }
    }
  })();
'

npm run test:integration
