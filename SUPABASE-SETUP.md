# Supabase Setup

This repo runs against a **local-only** Supabase project. There is no hosted/linked Supabase project
for this card — `supabase link` must never be run here, and `supabase/config.toml` has no project
ref or hosted URL (`project_id = "zyndio-local"` is a local-only identifier). A live dev project is
tracked separately and out of scope until it exists.

## 1. Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) (`supabase --version`)
- Docker (the CLI runs Postgres/GoTrue/Storage/etc. in containers)
- Deno (for Edge Functions — `which deno`)

## 2. Start the local stack

From the repo root:

```bash
supabase start
```

This brings up Postgres, GoTrue (auth), Storage, Studio, Inbucket, and the Edge Functions runtime
from `supabase/config.toml`. Notable local-only settings in that file:

- `[auth] enable_signup = false` — the web admin is invite-only; there is no public sign-up route
  (GoTrue's own `/signup` endpoint is also closed, not just hidden in the UI).
- `[auth.mfa] max_enrolled_factors = 1`, `[auth.mfa.totp] enroll_enabled = true` /
  `verify_enabled = true` — one TOTP authenticator per account.
- `[auth.hook.mfa_verification_attempt]` — a Postgres function hook backs the server-side
  5-attempt/15-minute lockout shared across password, TOTP, and recovery-code checks.

Get your local URL/keys at any time with:

```bash
supabase status
```

CI may start the stack with `-x <service>` to skip services this card doesn't exercise (e.g.
`storage`, `inbucket`) — the defaults in `config.toml` are the full local-dev set.

## 3. Apply the schema

```bash
supabase db reset
```

Applies every migration in `supabase/migrations/` (in order) to a fresh local database. This is the
**only** supported way to get the TC-005 schema/RLS policies into your local database — do not run
anything under `supabase/_legacy/` (pre-TC-005 SQL for tables the old patient-app pages still use;
kept for reference only, `git mv`'d out of the active migration path, see
[`supabase/_legacy/README.md`](./supabase/_legacy/README.md)). Re-run `supabase db reset` any time
you pull new migrations or want a clean slate.

## 4. Run the test suites

```bash
supabase test db                   # pgTAP: schema, RLS, role matrix, lockout, recovery codes, audit log
npm run lint && npm test           # web admin unit/component tests
bash scripts/integration-local.sh  # vitest integration tests against this local stack + Edge Functions
```

See the root [README.md](./README.md#local-supabase--integration-tests) for what each of these
covers and how `scripts/integration-local.sh` sources its own env.

## 5. Configure environment variables

```bash
cp .env.example .env
```

Fill in `.env` with the values from `supabase status`:

```
VITE_SUPABASE_URL=<API URL from `supabase status`>
VITE_SUPABASE_ANON_KEY=<anon key from `supabase status`>
SUPABASE_SERVICE_KEY=<service_role key from `supabase status`>
ADMIN_EMAIL=<email for your local admin account>
ADMIN_PASSWORD=<strong password — 12+ chars, upper/lower/number/symbol, not on the common-password blocklist>
```

Never commit `.env` (it's gitignored) and never put a real/shared password in it.

For the Flutter app, also copy and fill `flutter_app/dart_defines.example.json` →
`flutter_app/dart_defines.json` (gitignored) with the same Supabase URL/anon key, pointed at your
local stack (`http://127.0.0.1:54321` by default) for local runs.

## 6. Create the first admin

```bash
npm run admin:setup
```

See [admin-setup.md](./admin-setup.md) for what this does, the credentials model, and how every
subsequent account is created via an in-app invite instead.

## 7. Stop the stack

```bash
supabase stop
```

`supabase stop --no-backup` also discards the local database if you want a truly clean restart
(equivalent to never having run `supabase db reset`).
