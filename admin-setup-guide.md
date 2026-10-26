# Admin Access Setup Guide

This guide covers creating and testing an admin user for Zyndio's Supabase-backed admin panel.

## Credentials

There is no default admin account. Credentials come entirely from environment variables:

- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`

Set both in `.env` (see [.env.example](./.env.example)) before running any admin script — the scripts
refuse to run if either is missing.

## Create the admin user

With a Supabase project configured (see [SUPABASE-SETUP.md](./SUPABASE-SETUP.md)) and `.env` populated:

```bash
npm run admin:setup
```

This runs `scripts/supabase-admin-setup.ts`, which creates the Supabase auth user for `ADMIN_EMAIL`
(if it doesn't already exist) and sets its `profiles.role` to `admin`.

`npm run admin:setup` is the only script that reads `ADMIN_EMAIL`/`ADMIN_PASSWORD` from the
environment — prefer it. Two other scripts exist for one-off local fixes and are **not**
environment-driven:

- `npm run admin:fix` (`scripts/fix-admin-role.ts`) promotes a hardcoded email to `admin`. Edit the
  email in the script before running it.
- `npm run admin:force` (`scripts/force-admin.ts`) promotes **every** Supabase user to `admin`. Only
  ever run this against a disposable dev project, never against staging or production.

## Testing admin access

### Local

1. Start the dev server: `npm run dev`
2. Open http://localhost:3001/login
3. Sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`
4. You should be redirected to `/admin`

### Production

1. Open `https://<your-deployment>/login`
2. Sign in with the same credentials
3. Verify redirect to `/admin`

## Troubleshooting

**"Invalid credentials"** — confirm `ADMIN_EMAIL` / `ADMIN_PASSWORD` match what's in `.env`, and that
`npm run admin:setup` completed without error.

**Redirected to `/` instead of `/admin`** — the user's `profiles.role` isn't `admin`. Re-run
`npm run admin:setup` (it fixes the role for an existing `ADMIN_EMAIL` user too), then sign in again.

**Need to inspect the database directly** — `npm run db:check` runs `scripts/check-db.ts` against the
Supabase project configured in `.env`.

## Security

- Never commit `.env` or any file containing real credentials.
- Use a strong, unique password for `ADMIN_PASSWORD` and store it in a password manager.
- Rotate the admin password periodically and use separate accounts (with `role` values like `doctor`,
  `nutritionist`) for team members instead of sharing the admin account.
