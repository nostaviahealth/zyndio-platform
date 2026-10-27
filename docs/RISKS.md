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
