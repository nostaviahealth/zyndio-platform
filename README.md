# Zyndio

Zyndio is a health & longevity platform with a Flutter patient app and a React/Vite admin web app, both backed by Supabase.

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

No default credentials are provided anywhere in this repo. Admin access is always bootstrapped from the `ADMIN_EMAIL` / `ADMIN_PASSWORD` environment variables — see [admin-setup-guide.md](./admin-setup-guide.md).

## Root admin web app (Vite)

```bash
npm run dev        # dev server
npm run lint        # tsc --noEmit
npm test            # vitest run
npm run build        # production build
```

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
