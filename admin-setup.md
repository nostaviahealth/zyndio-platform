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
  characters, an uppercase and a lowercase letter, a number, a symbol (enforced by GoTrue's
  `password_requirements`, `supabase/config.toml`), and rejected if it's on the server-side
  common-password blocklist (`public.password_is_blocked`). There's no way to bypass this check.
- Every account after the first is created via an **invite**, from inside the admin app
  (`org_admin` → Users & roles → Invite), never via a script or env var.
- **Changing a password after the initial set (invite acceptance / bootstrap) should go through the
  `change-password` Edge Function, never `supabase.auth.updateUser({ password })` directly.** The
  web client has no other password-change path; don't add one. `change-password` verifies the
  caller's own session and re-runs the same length/blocklist check before calling the admin API.
  **Known accepted gap (M8, tracked on TC-011):** this is enforced in our own client code, not at
  the database/GoTrue level. A freshly-signed-in session can still call
  `supabase.auth.updateUser({ password })` (or `PUT /auth/v1/user`) directly - GoTrue's character-
  class rule still applies, but our common-password blocklist and audit log are both skipped. See
  `work/.claude-runs/tc005/m8/OBSERVED.md` for the probe that confirmed this locally. Accepted until
  before any real patient data; fix options are paid-plan leaked-password protection or gating every
  password change server-side through the audited function.

## Bootstrap the first org admin

With a Supabase project running (local: `supabase start`; see [SUPABASE-SETUP.md](./SUPABASE-SETUP.md))
and `.env` populated with `VITE_SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`:

```bash
npm run admin:setup
```

This runs `scripts/supabase-admin-setup.ts`, which:

1. Refuses to run if `ADMIN_EMAIL`/`ADMIN_PASSWORD` are missing, or if `ADMIN_PASSWORD` fails the
   length/blocklist check (GoTrue separately enforces the character-class rule when the user is
   created).
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

Deactivate/reactivate are org-admin-app actions (`deactivate-user`, `reactivate-user` Edge
Functions). Resetting someone's 2FA is split across two roles:

- **An org admin can only *request* a reset**, via the `request_mfa_reset` RPC. This writes an
  `mfa_reset_requested` audit row and a `notification_outbox` row to every Zyndio (platform) admin.
  It touches no factor and no recovery code — nothing about the target's 2FA actually changes.
- **Only a Zyndio admin can perform the reset itself**, via the `reset-mfa` Edge Function: deletes
  the target's TOTP factor(s) and old recovery codes, forces global sign-out, flags mandatory
  re-enrollment, and audit-logs + notifies the target. An org admin calling `reset-mfa` directly
  gets 403.
- **Resetting your own 2FA is rejected server-side** (403) for a Zyndio admin too, not just hidden
  in the UI — use the normal recovery-code flow for yourself instead.
- Deactivating a member also revokes any pending invite for them, so a still-live invite link can't
  silently reverse the deactivation. Deactivating/reactivating is audit-logged and, for
  deactivation, forces a global sign-out. The last active `org_admin` in an org cannot be
  deactivated.

### Zyndio (platform) admin

`platform_admins` is a separate, internal table from `org_members` — being an `org_admin` of an
organization does **not** make someone a Zyndio admin. There is no in-app action that grants this
role and no default/seeded row. The only way to create one locally is:

```bash
ZYNDIO_PLATFORM_ADMIN=true npm run admin:setup
```

run against the email that should hold it (it can be the same email as the first org admin, or a
different one — a Zyndio admin does not need to be a member of any organization at all). This is a
platform-operator concern, not a per-org one; grant it sparingly.

## Troubleshooting

**"ADMIN_PASSWORD is too short" / "is too common (on the server-side blocklist)" / GoTrue's
"Password should contain at least one character of each..."** — pick a password that's at least 12
characters, has an uppercase and a lowercase letter, a number and a symbol, and isn't on common
password lists; the checks run server side and can't be skipped.

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
