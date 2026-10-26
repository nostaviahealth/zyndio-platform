# Admin Setup

How the first Zyndio org admin is created, and how subsequent staff accounts are managed. The web
admin app is invite-only: there is no public sign-up route, and no default or env-seeded admin
password is ever baked into a build.

## Credentials model

- `ADMIN_EMAIL` / `ADMIN_PASSWORD` (required) — the first org admin's sign-in credentials. Read from
  the environment only, never hardcoded. Set them in `.env` (see [.env.example](./.env.example)).
- `ORG_NAME` (optional) — name for the first organization if one doesn't exist yet. Defaults to
  `Zyndio`.
- `ADMIN_PASSWORD` is validated the same way an invited user's own password-set is: at least 12
  characters, and rejected if it's on the server-side common/leaked-password blocklist
  (`public.password_is_blocked`). There's no way to bypass this check.
- Every account after the first is created via an **invite**, from inside the admin app
  (`org_admin` → Users & roles → Invite), never via a script or env var.

## Bootstrap the first org admin

With a Supabase project running (local: `supabase start`; see [SUPABASE-SETUP.md](./SUPABASE-SETUP.md))
and `.env` populated with `VITE_SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`:

```bash
npm run admin:setup
```

This runs `scripts/supabase-admin-setup.ts`, which:

1. Refuses to run if `ADMIN_EMAIL`/`ADMIN_PASSWORD` are missing, or if `ADMIN_PASSWORD` fails the
   length/blocklist check.
2. Creates the `auth.users` row for `ADMIN_EMAIL` (or reuses it if it already exists).
3. Creates the first `organizations` row (or reuses the first/only one that exists).
4. Creates the `org_members` row: `role = org_admin`, `status = active`.
5. Enrolls **no** two-factor authenticator. The bootstrap admin goes through the normal 02-2fa-setup
   flow (scan → verify → recovery codes) on first sign-in, exactly like anyone who accepts an invite.

The script is idempotent: re-running it against an email that's already an org member is a no-op. It
never forcibly changes an existing member's role or org — if `ADMIN_EMAIL` already belongs to a
different org or role than expected, the script reports that and stops rather than silently
"fixing" it.

There used to be `npm run admin:fix` and `npm run admin:force` scripts for ad hoc local
role-patching. Both are **removed**: `admin:force` in particular promoted every Supabase user to
admin, which is incompatible with one-role-per-person and would silently wreck RLS. If you need to
change someone's role, use the admin app's role-change action (`change_member_role`), which is
audited.

## First sign-in

1. Start the admin app: `npm run dev`
2. Open http://localhost:3001/admin/login
3. Sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`
4. Complete authenticator (TOTP) setup when prompted — scan the QR code, verify a code, save the 10
   recovery codes somewhere safe. Sign-in isn't complete (aal2) until this step is done.
5. You land on `/admin/users` (Users & roles) as `org_admin`.

## Inviting subsequent users

From `/admin/users`, invite by email + role (`org_admin`, `physician`, `care_coordinator`,
`read_only`). This calls the `invite-user` Edge Function, which creates their account in `invited`
status and a 7-day invite token; they set their own password via the invite link
(`accept-invite`) and enroll their own authenticator on first sign-in. No password or MFA secret
is ever handled by an admin or a script on another person's behalf.

## Resetting someone's two-factor / deactivating someone

Both are admin-app actions (`reset-mfa`, `deactivate-user`, `reactivate-user` Edge Functions), not
scripts:

- An org admin can reset another member's 2FA (forces TOTP re-enrollment, signs them out globally,
  audit-logged). **Resetting your own 2FA is rejected server-side** (403), not just hidden in the
  UI — use the normal recovery-code flow for yourself instead.
- Deactivating/reactivating a member is audit-logged and, for deactivation, forces a global sign-out.
  The last active `org_admin` in an org cannot be deactivated.

## Troubleshooting

**"ADMIN_PASSWORD is too short" / "is a common/leaked password"** — pick a password that's at least
12 characters and isn't on common password lists; the check runs server side and can't be skipped.

**`admin:setup` says the email is already a member of a different org/role than expected** — the
script won't overwrite this for you. Decide intentionally (new email instead, or a role change via
the admin app) rather than forcing it.

**Need to inspect the database directly** — `npm run db:check` runs `scripts/check-db.ts`.

## Security

- Never commit `.env` or any file containing real credentials.
- Use a strong, unique password for `ADMIN_PASSWORD` and store it in a password manager.
- `admin:setup` is meant to be run once per environment, to create the *first* admin. Every
  subsequent account — including additional org admins — should come from an in-app invite, so
  there's always an audit trail of who granted access to whom.
