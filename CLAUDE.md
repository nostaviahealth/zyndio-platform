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
flutter build apk --debug --dart-define-from-file=dart_defines.json
flutter build web --dart-define-from-file=dart_defines.json
```

Root admin web app:
```bash
npm run lint      # tsc --noEmit
npm test          # vitest run
npm run build
```

`space/`:
```bash
cd space && npm run lint && npm run build
```

Security:
```bash
gitleaks git --config .gitleaks.toml --redact
bash scripts/leak-scan.sh
```

## Rules

- No secrets, API keys, or credentials in code or docs. Env vars only: `.env` (root), `flutter_app/dart_defines.json`. Both are gitignored — never commit them.
- No default admin credentials anywhere. Admin access always comes from `ADMIN_EMAIL` / `ADMIN_PASSWORD`.
- Use only fictional patient/health data in examples, fixtures, and docs — never real PII.
- The old product brand name must never appear in code, docs, assets, or generated builds. `scripts/leak-scan.sh` enforces this.
- All changes land via pull request — never push directly to `main`.
- Never weaken, skip, or delete a test to make it pass. Fix the underlying issue instead.
- Don't edit generated Android/iOS/web icon or splash assets by hand — regenerate them via `dart run flutter_launcher_icons` / `dart run flutter_native_splash:create` after changing source art in `flutter_app/assets/icons/` or the config in `flutter_app/pubspec.yaml`.

## Docs

- [README.md](./README.md) — setup, prerequisites, run/test/build commands.
- [SUPABASE-SETUP.md](./SUPABASE-SETUP.md) — standing up a dev Supabase project.
- [admin-setup-guide.md](./admin-setup-guide.md) — creating and troubleshooting admin access.
- [PROACTIVE_INTELLIGENCE.md](./PROACTIVE_INTELLIGENCE.md) — feature documentation for the notification/coaching engine.
