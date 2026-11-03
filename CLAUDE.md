# Zyndio

Health & longevity platform: a Flutter patient app plus a React/Vite admin web app, both on Supabase.

## Stack

- **flutter_app/** — Flutter patient app (iOS/Android/web), Riverpod, go_router, Supabase, Firebase.
- **packages/** — shared Flutter packages (e.g. `platform_wearables`).
- Root (`components/`, `pages/`, `contexts/`, `lib/`, `src/`) — React + TypeScript + Vite admin web app.
- **space/** — separate React/Vite companion web app.
- **supabase/** — SQL schema, migrations, functions.
- **scripts/** — tsx admin/db scripts and bash CI gates (`analyze-gate.sh`, `leak-scan.sh`).

## Commands

Flutter (`cd flutter_app` unless noted):
```bash
bash scripts/analyze-gate.sh                                             # analyzer gate (from repo root)
flutter test
flutter test --dart-define=DEMO_BUILD=true                               # demo-only flows (kDemoBuild gated)
flutter build apk --debug --dart-define-from-file=dart_defines.json
flutter build web --dart-define-from-file=dart_defines.json
```

Local Supabase (`supabase start` first — see [SUPABASE-SETUP.md](./SUPABASE-SETUP.md)):
```bash
supabase db reset && supabase test db   # reapply migrations + run pgTAP suite (supabase/tests/*.sql)
bash scripts/integration-local.sh       # vitest integration suite against the local stack + Edge Functions
```

Root admin web app:
```bash
npm run lint             # tsc --noEmit
npm test                 # vitest run (unit/component)
npm run build             # production bundle (preview harness excluded)
npm run build:preview      # --mode preview build (adds the screenshot/preview harness)
npm run admin:setup       # bootstrap the first org admin — see admin-setup.md
```

`space/`:
```bash
cd space && npm run lint && npm run build
```

Security:
```bash
gitleaks git --config .gitleaks.toml --redact
bash scripts/leak-scan.sh          # fails (not skips) if a required build output is missing
bash scripts/test-leak-scan.sh     # self-test proving the above
python3 scripts/check-no-external-web-assets.py [dist space/dist]  # no CDN script/style/import map (TC-032)
bash scripts/test-check-no-external-web-assets.sh                 # self-test proving the above
```

## Rules

- No secrets, API keys, or credentials in code or docs. Env vars only: `.env` (root), `flutter_app/dart_defines.json`. Both are gitignored — never commit them.
- No default admin credentials anywhere. Admin access always comes from `ADMIN_EMAIL` / `ADMIN_PASSWORD`.
- Use only fictional patient/health data in examples, fixtures, and docs — never real PII.
- The old product brand name must never appear in code, docs, assets, or generated builds. `scripts/leak-scan.sh` enforces this.
- All changes land via pull request — never push directly to `main`.
- Never weaken, skip, or delete a test to make it pass. Fix the underlying issue instead.
- App launcher icons (iOS `AppIcon.appiconset`, Android `mipmap-*` + `mipmap-anydpi-v26`, web `public/` favicons + `site.webmanifest`, `store-assets/`) are installed verbatim from the design handoff and pinned by `scripts/check-app-icons.sh` / `scripts/app-icons.sha256` (TC-023). Don't edit them by hand or add `flutter_launcher_icons` back; replace them only from a new handoff and update the pins in the same PR.
- Don't edit generated splash assets by hand — regenerate them via `dart run flutter_native_splash:create` after changing source art in `flutter_app/assets/icons/` or the config in `flutter_app/pubspec.yaml`.

## Docs

- [README.md](./README.md) — setup, prerequisites, run/test/build commands.
- [SUPABASE-SETUP.md](./SUPABASE-SETUP.md) — standing up a dev Supabase project.
- [admin-setup.md](./admin-setup.md) — creating and troubleshooting admin access.
- [PROACTIVE_INTELLIGENCE.md](./PROACTIVE_INTELLIGENCE.md) — feature documentation for the notification/coaching engine.
