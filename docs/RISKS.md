# Risks register (Zyndio)

## R-AUTH-M8 — Free-plan direct password update bypasses blocklist and audit

- **Status:** Accepted until before any real patient data (TC-011 / Henry).
- **Found:** Clara sign-in E2E + M8 review of `04e6843` / local GoTrue.
- **What happens:** A freshly signed-in user can call Supabase Auth `PUT /auth/v1/user` with `{ "password": "…" }` directly. On the free plan this path does **not** run our HaveIBeenPwned-style blocklist and does **not** write a password-change audit row. Our invite UI and `change-password` edge function do both correctly.
- **Mitigations already in place (M8 on PR #4):**
  - `password_requirements = lower_upper_letters_digits_symbols` (min length 12 + character classes) on every GoTrue password-set path.
  - `[auth.email] secure_password_change = true` (re-auth window for email password change flows that honour it).
  - App password changes go through `change-password` (blocklist + audit).
- **Fix-by:** before any real patient data.
- **Fix options (do not hide this):**
  1. Paid-plan GoTrue leaked-password protection so direct `PUT /auth/v1/user` rejects common passwords, and/or
  2. Route every password change through our audited edge function and stop the client from calling GoTrue's password update directly (server-side enforcement still needed for a determined caller).
- **Tracking:** TC-011 item 7; Clara `test.fail` in `e2e/specs/08-password-m8.spec.ts` until a real fix lands.
- **Owner:** Leo / Henry accept.

## R-OUTBOX-JWT — process-outbox JWT signature + gateway check

- **Status:** Mitigated in app (TC-011): `process-outbox` verifies HS256 with `JWT_SECRET` and rejects bad signatures (fail-first Deno test).
- **Ops requirement:** The API gateway's JWT verification must stay enabled in every deployed environment. The in-function check is defense in depth for direct invocation (e.g. local `functions serve` or a misconfigured gateway).

## R-CORS-ADMIN-ORIGIN — Edge Functions CORS allowlist needs a real admin origin in production

- **Status:** Mitigated in app (TC-011 L11): `supabase/functions/_shared/cors.ts` reflects the request's `Origin` only when it matches a fixed list of local admin dev origins (`127.0.0.1`/`localhost` on `5173`/`3100`) or the `ADMIN_ORIGIN`/`SITE_URL` env var. `Access-Control-Allow-Origin: *` is gone.
- **Ops requirement:** Every deployed environment (staging, production) must set `ADMIN_ORIGIN` (or `SITE_URL`) to the real deployed admin app origin, or every cross-origin call from the deployed admin app will be blocked by the browser.
- **Owner:** Leo / deploy checklist.

## R-CLIENT-IP — per-IP rate limits depend on the proxy chain

- **Status:** Mitigated in app (security-hardening): `supabase/functions/_shared/clientIp.ts` no longer trusts the caller-supplied first `x-forwarded-for` hop (or `x-real-ip`), which let any client pick a fresh IP per request and bypass the per-IP limits on patient sign-up, sign-in, password reset, email change and link-code requests. It now reads the hop appended by the gateway, skipping `TRUSTED_PROXY_HOPS` extra trusted proxies (default 0). `supabase/proxy-worker.js` now replaces the caller's `x-forwarded-for` with Cloudflare's `CF-Connecting-IP`.
- **Ops requirement:** Environments reached through the Cloudflare proxy worker must set `TRUSTED_PROXY_HOPS=1` on the Edge Functions (`supabase secrets set TRUSTED_PROXY_HOPS=1`); otherwise every proxied visitor shares the worker's IP bucket. Direct-to-Supabase environments leave it unset. Per-email limits are unaffected either way.
- **Owner:** Leo / deploy checklist.

## R-REVENUECAT-ORDERING — webhook events are deduplicated and ordered

- **Status:** Fixed (security-hardening): `public.apply_revenuecat_event` records each RevenueCat event id (duplicates are no-ops) and only writes premium state for an event newer than the last one applied, so a delayed EXPIRATION can no longer downgrade a renewed patient. EXPIRATION now always revokes (its `entitlement_ids` still list the expired entitlement, which used to keep patients premium), CANCELLATION keeps access until `expiration_at_ms`, `subscription_expires_at` is written, and a crash returns 5xx so RevenueCat retries.
- **Ops requirement:** RevenueCat must send real event ids and `event_timestamp_ms` (it does for every event type); payloads without them are acknowledged and ignored, and logged.
