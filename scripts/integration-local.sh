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
# - Warm-up (ci-integration-warmup): creates a throwaway fictional local
#   account (warmup-<time>@example.test, random password generated at run
#   time, never printed), signs it in, and makes logged-in requests to the
#   edge functions the tests call (invite-user first). Every function must
#   answer 3 times in a row with a non-5xx status. A refused connection or
#   any 5xx (502/503 included) resets that function's count. Polls every
#   0.5s; if not ready within 60s the run fails. The account is deleted
#   afterwards. No token, key or password is ever echoed or logged.
#   Individual test assertions are never retried.
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

# Logged-in warm-up via node's built-in fetch (never curl, nothing verbose).
# Only HTTP status codes and function names are ever printed.
node -e '
  const crypto = require("node:crypto");
  const API = process.env.SUPABASE_URL;
  const FN = process.env.SUPABASE_FUNCTIONS_URL;
  const ANON = process.env.SUPABASE_ANON_KEY;
  const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;
  // invite-user first: it is the first function admin-actions.test.ts calls.
  const fns = ["invite-user", "reset-mfa", "deactivate-user", "reactivate-user", "change-password", "process-outbox"];
  const NEEDED = 3;
  const deadline = Date.now() + 60_000;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  class NotReady extends Error {}
  const fail = () => { throw new NotReady(); };
  const admin = (path, init = {}) => fetch(`${API}/auth/v1/${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", apikey: SERVICE, Authorization: `Bearer ${SERVICE}` },
  });

  (async () => {
    // Fictional local-only account; password is random per run and never printed.
    const email = `warmup-${Date.now()}@example.test`;
    const password = "Wu-" + crypto.randomBytes(24).toString("base64url") + "-9aZ!";
    let userId = null;
    let token = null;
    let ok = true;
    try {
      while (!token) {
        if (Date.now() > deadline) fail();
        try {
          if (!userId) {
            const res = await admin("admin/users", {
              method: "POST",
              body: JSON.stringify({ email, password, email_confirm: true }),
            });
            if (res.ok) userId = (await res.json()).id;
          }
          if (userId) {
            const res = await fetch(`${API}/auth/v1/token?grant_type=password`, {
              method: "POST",
              headers: { "Content-Type": "application/json", apikey: ANON },
              body: JSON.stringify({ email, password }),
            });
            if (res.ok) token = (await res.json()).access_token || null;
          }
        } catch {
          // auth not reachable yet
        }
        if (!token) await sleep(500);
      }

      const streak = Object.fromEntries(fns.map((f) => [f, 0]));
      while (fns.some((f) => streak[f] < NEEDED)) {
        if (Date.now() > deadline) fail();
        for (const f of fns) {
          if (streak[f] >= NEEDED) continue;
          try {
            const res = await fetch(`${FN}/${f}`, {
              method: "POST",
              headers: { "Content-Type": "application/json", apikey: ANON, Authorization: `Bearer ${token}` },
              body: "{}",
            });
            await res.text();
            streak[f] = res.status < 500 ? streak[f] + 1 : 0;
          } catch {
            streak[f] = 0; // connection refused / not listening yet
          }
        }
        if (fns.some((f) => streak[f] < NEEDED)) await sleep(500);
      }
      console.log(`integration-local: edge functions warm (${NEEDED} consecutive non-5xx logged-in answers each: ${fns.join(", ")})`);
    } catch (e) {
      ok = false;
      if (!(e instanceof NotReady)) console.error("integration-local: warm-up error (details withheld)");
    } finally {
      if (userId) {
        try { await admin(`admin/users/${userId}`, { method: "DELETE" }); } catch { /* best effort */ }
      }
    }
    if (!ok) {
      console.error("integration-local: edge functions still returning 502/503 (or unreachable) after 60s");
      process.exit(1);
    }
    process.exit(0);
  })();
'

npm run test:integration
