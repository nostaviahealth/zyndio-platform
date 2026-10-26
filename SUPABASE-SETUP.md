# Supabase Setup

Steps to stand up a fresh Zyndio dev Supabase project and point this repo at it.

## 1. Create the project

1. Go to https://supabase.com/dashboard and click **New Project**.
2. Pick an org, name it (e.g. `zyndio-dev`), set a database password, and choose a region.
3. Wait for provisioning to finish.

## 2. Get your credentials

In **Settings → API**, copy:

- **Project URL**
- **anon/public key**
- **service_role/secret key** — never commit this; it's server-side only

## 3. Configure environment variables

```bash
cp .env.example .env
```

Fill in `.env`:

```
VITE_SUPABASE_URL=<your project URL>
VITE_SUPABASE_ANON_KEY=<your anon key>
SUPABASE_SERVICE_KEY=<your service_role key>
ADMIN_EMAIL=<email for your local admin account>
ADMIN_PASSWORD=<strong password>
```

For the Flutter app, also copy and fill `flutter_app/dart_defines.example.json` →
`flutter_app/dart_defines.json` (gitignored) with the same `SUPABASE_URL` / `SUPABASE_ANON_KEY` plus
any third-party keys you need locally.

## 4. Run the database schema

In the Supabase dashboard **SQL Editor**, run the contents of [`supabase/schema.sql`](./supabase/schema.sql).

Alternatively, run the automated setup script, which applies schema and creates the admin user in one
step:

```bash
npm install
npm run setup:all
```

(`npm run setup:db` applies schema only; `npm run db:check` runs a sanity check against the schema.)

## 5. Enable email auth

**Authentication → Providers → Email**: ensure it's enabled. For local dev, you can disable
"Enable email confirmations" under **Email** settings so signups work without SMTP configured.

## 6. Configure auth URLs

**Authentication → URL Configuration**:

- **Site URL**: your deployed URL (or `http://localhost:3001` for local-only dev)
- **Redirect URLs**: add `http://localhost:3001/**` and your deployed URL + `/**`

## 7. Create the admin user

```bash
npm run admin:setup
```

See [admin-setup.md](./admin-setup.md) for details and troubleshooting.
