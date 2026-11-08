# Zyndio

Zyndio is a health & longevity platform with a Flutter patient app and a React/Vite admin web app, both backed by Supabase.

> **Picking the project up?** Start with [PROJECT_STATUS.md](./PROJECT_STATUS.md): what is done, what is left, and what is waiting on others.

## Prerequisites

- Flutter 3.47.8 (stable channel)
- JDK 17
- Android SDK 36 (compileSdk 36, targetSdk 35)
- Node.js 20+

## Repository layout

```
flutter_app/        # Flutter patient app (iOS, Android, web)
packages/            # Shared Flutter packages (e.g. platform_wearables)
space/               # React/Vite companion web app
supabase/            # Database schema, migrations, SQL functions
scripts/             # Node/tsx admin + db scripts, analyze-gate.sh, leak-scan.sh
components/, pages/, contexts/, lib/, src/   # Root Vite admin web app
```

## Setup

1. Copy env files:
   ```bash
   cp .env.example .env
   cp flutter_app/dart_defines.example.json flutter_app/dart_defines.json
   ```
   Fill in your own Supabase project values and keys — see [SUPABASE-SETUP.md](./SUPABASE-SETUP.md).
   `dart_defines.json` is gitignored; never commit it.
2. Install root web dependencies:
   ```bash
   npm install
   ```
3. Fetch Flutter dependencies:
   ```bash
   cd flutter_app && flutter pub get
   cd ../packages/platform_wearables && flutter pub get
   ```

No default credentials are provided anywhere in this repo. Admin access is always bootstrapped from the `ADMIN_EMAIL` / `ADMIN_PASSWORD` environment variables — see [admin-setup.md](./admin-setup.md).

### TC-012 deploy note (Henry)

Record-matching HMAC pepper lives in Supabase Vault as `link_code_pepper` — create it per
environment at deploy time (never commit a real value). Full steps:
[SUPABASE-SETUP.md § Deploy checklist](./SUPABASE-SETUP.md#deploy-checklist-henry--tc-012-record-matching)
and [docs/RECORD_MATCHING.md](./docs/RECORD_MATCHING.md).
Also set `ZYNDIO_DEFAULT_ORG_ID` (or supply `orgId` from the telehealth connector); there is
no silent default org UUID.


### INT-01/02 deploy note (partner API + webhooks)

The zyndio.com server integration (`partner-api` + `deliver-webhooks` Edge Functions) needs two
Vault secrets per environment (`webhook_worker_url`, `webhook_worker_service_key`) and
`verify_jwt = false` for `partner-api` only. Full reference and checklist:
[docs/PARTNER_API.md](./docs/PARTNER_API.md).

## Root admin web app (Vite)

```bash
npm run dev          # dev server
npm run lint         # tsc --noEmit
npm test             # vitest run (unit/component tests)
npm run build        # production build
npm run build:preview  # --mode preview build; adds the /__preview screenshot harness
                        # (dead-code-eliminated from `npm run build`, see tests/preview/)
```

### Local Supabase + integration tests

This repo targets a **local-only** Supabase project — no hosted/linked project is used (see
[SUPABASE-SETUP.md](./SUPABASE-SETUP.md)).

```bash
supabase start                   # once per session
supabase db reset                # (re)apply supabase/migrations/* from scratch
supabase test db                 # pgTAP suite in supabase/tests/*.sql (RLS + role matrix, lockout,
                                  # recovery codes, audit log, etc.)
bash scripts/integration-local.sh  # vitest integration suite (tests/integration/*.test.ts) against
                                    # the local stack; starts/stops `supabase functions serve` itself
```

`scripts/integration-local.sh` reads Supabase URL/keys from `supabase status -o env` into its own
process only (never written to a file or passed on a command line). The integration suite
(`npm run test:integration`) skips itself with a visible message if `SUPABASE_URL`/keys aren't in
the environment and `CI` isn't set; in CI, missing env is a hard failure.

## `space/` web app

```bash
cd space
npm install
npm run lint
npm run build
```

## Flutter app

```bash
cd flutter_app
flutter test
flutter build apk --debug --dart-define-from-file=dart_defines.json
flutter build web --dart-define-from-file=dart_defines.json
```

Run the analyzer gate (used in CI) from the repo root:
```bash
bash scripts/analyze-gate.sh
```

#### Demo build flag

`lib/main_demo.dart` (the screenshot/demo entrypoint) must always be built/run with
`--dart-define=DEMO_BUILD=true`:

```bash
flutter build web -t lib/main_demo.dart --dart-define=DEMO_BUILD=true
```

`kDemoBuild` is a compile-time const (`lib/demo/demo_build_flag.dart`) that gates demo-only auto
sign-in and debug-code-display behind the flag so they're tree-shaken out of every non-demo build —
`flutter test` proves both are no-ops when the flag is false (default). Run the demo-flow tests with
the flag on too:

```bash
flutter test --dart-define=DEMO_BUILD=true
```

`scripts/demo-screenshots.sh` / `scripts/demo_screenshots.py` / `scripts/demo_screenshots_admin.py`
already build with this flag — don't build `main_demo.dart` any other way.

## Security checks

```bash
bash scripts/leak-scan.sh          # fails if the old brand name appears anywhere tracked/built
gitleaks git --config .gitleaks.toml --redact
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request:
- `flutter`: analyze gate, `flutter test`, debug APK build, Flutter web build
- `web`: lint/test/build for the root admin app and `space/`
- `secrets`: gitleaks scan
- `leak-scan`: builds all web/APK artifacts and scans them for old-brand references

All changes land via pull request — direct pushes to `main` are not used.

## License

All rights reserved — Zyndio
