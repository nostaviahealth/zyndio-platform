// TC-019: idempotent fictional seed for the real-app theme/focus/layout/axe
// check (scripts/tc019_theme_check.py). Pattern follows
// .claude-runs/tc019/ref-seed-pattern.mts (admin users API + TOTP enrol).
//
// Local Supabase only. Never touches clara-qa. Creates exactly one fictional
// org ("TC-019 Care Team (fictional)") and a handful of *@example.test
// members. Generated passwords/TOTP secrets are written only to
// /tmp/tc019-creds.json (0600) - never to the repo, never printed.
//
// Idempotent: if /tmp/tc019-creds.json already points at users that still
// resolve in the DB, it's reused as-is (refreshing the invited member's
// created_at so the "N days left" badge stays meaningful). Otherwise
// everything is (re)created.
//
// TC-019 fix round (F1): two more fictional rows so every row action exists
// on a row that can be placed LAST in the table (list_org_members orders by
// created_at): an active "last-active" row (Request two-factor reset,
// Deactivate) and a deactivated row (Reactivate); the invited row has
// Cancel invite. `--last <invited|lastActive|deactivated>` bumps that row's
// created_at so it is the last row; without it the invited row is last.
import { randomBytes, createHmac } from 'node:crypto';
import { writeFileSync, chmodSync, readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

// Reads the already-running local stack's URL/keys straight from `supabase
// status -o env` into process memory only - never written to a file, never
// logged. Falls back to pre-set env vars (e.g. a caller that already ran
// `supabase status` itself) so this also works under test harnesses that
// inject the values directly.
function loadSupabaseEnv(): { url: string; anon: string; serviceRole: string } {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return {
      url: process.env.SUPABASE_URL,
      anon: process.env.SUPABASE_ANON_KEY,
      serviceRole: process.env.SUPABASE_SERVICE_ROLE_KEY,
    };
  }
  const out = execFileSync('supabase', ['status', '-o', 'env'], { encoding: 'utf8' });
  const vars: Record<string, string> = {};
  for (const line of out.split('\n')) {
    const m = line.match(/^([A-Z_]+)="(.*)"$/);
    if (m) vars[m[1]] = m[2];
  }
  if (!vars.API_URL || !vars.ANON_KEY || !vars.SERVICE_ROLE_KEY) {
    throw new Error('could not read API_URL/ANON_KEY/SERVICE_ROLE_KEY from `supabase status -o env`');
  }
  return { url: vars.API_URL, anon: vars.ANON_KEY, serviceRole: vars.SERVICE_ROLE_KEY };
}

const { url: URL_, anon: ANON, serviceRole: SR } = loadSupabaseEnv();
const CREDS_PATH = '/tmp/tc019-creds.json';

function h(key: string, token = key): Record<string, string> {
  return { 'Content-Type': 'application/json', apikey: key, Authorization: `Bearer ${token}` };
}

async function j(r: Response): Promise<any> {
  const t = await r.text();
  if (!r.ok) throw new Error(`${r.status} ${r.url} ${t}`);
  return t ? JSON.parse(t) : null;
}

const rest = (p: string, b: unknown) =>
  fetch(`${URL_}/rest/v1/${p}`, {
    method: 'POST',
    headers: { ...h(SR), Prefer: 'return=representation' },
    body: JSON.stringify(b),
  }).then(j);

const restUpsert = (p: string, b: unknown, onConflict: string) =>
  fetch(`${URL_}/rest/v1/${p}?on_conflict=${onConflict}`, {
    method: 'POST',
    headers: { ...h(SR), Prefer: 'return=representation,resolution=merge-duplicates' },
    body: JSON.stringify(b),
  }).then(j);

const rpc = (name: string, args: unknown) =>
  fetch(`${URL_}/rest/v1/rpc/${name}`, { method: 'POST', headers: h(SR), body: JSON.stringify(args) }).then(j);

const genPassword = () => 'Qa-' + randomBytes(12).toString('base64url') + '9!a';

async function createUser(email: string, password: string): Promise<string> {
  const created = await j(
    await fetch(`${URL_}/auth/v1/admin/users`, {
      method: 'POST',
      headers: h(SR),
      body: JSON.stringify({ email, password, email_confirm: true }),
    }),
  );
  return created.id as string;
}

function totp(secret: string): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of secret.replace(/=+$/, '')) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  const key = Buffer.from(bits.match(/.{8}/g)!.map((b) => parseInt(b, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const digest = createHmac('sha1', key).update(counter).digest();
  const offset = digest[19] & 15;
  const code = (digest.readUInt32BE(offset) & 0x7fffffff) % 1e6;
  return String(code).padStart(6, '0');
}

async function enrolTotp(email: string, password: string): Promise<string> {
  const session = await j(
    await fetch(`${URL_}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: h(ANON),
      body: JSON.stringify({ email, password }),
    }),
  );
  const factor = await j(
    await fetch(`${URL_}/auth/v1/factors`, {
      method: 'POST',
      headers: h(ANON, session.access_token),
      body: JSON.stringify({ factor_type: 'totp', friendly_name: 'tc019' }),
    }),
  );
  const challenge = await j(
    await fetch(`${URL_}/auth/v1/factors/${factor.id}/challenge`, {
      method: 'POST',
      headers: h(ANON, session.access_token),
    }),
  );
  await j(
    await fetch(`${URL_}/auth/v1/factors/${factor.id}/verify`, {
      method: 'POST',
      headers: h(ANON, session.access_token),
      body: JSON.stringify({ challenge_id: challenge.id, code: totp(factor.totp.secret) }),
    }),
  );
  return factor.totp.secret as string;
}

async function findUserId(email: string): Promise<string | null> {
  const rows = await rpc('find_user_id_by_email', { p_email: email });
  return (rows as string | null) ?? null;
}

interface Creds {
  orgId: string;
  orgAdmin: { email: string; password: string; totpSecret: string; userId: string };
  physician: { email: string; password: string; totpSecret: string; userId: string };
  coordinator: { email: string; userId: string };
  readOnly: { email: string; userId: string };
  invited: { email: string; userId: string };
  lastActive?: { email: string; userId: string };
  deactivated?: { email: string; userId: string };
}

type LastKey = 'invited' | 'lastActive' | 'deactivated';
const LAST_ARG = process.argv.indexOf('--last');
const LAST: LastKey = (LAST_ARG > -1 ? process.argv[LAST_ARG + 1] : 'invited') as LastKey;
if (!['invited', 'lastActive', 'deactivated'].includes(LAST)) throw new Error(`bad --last ${LAST}`);

const EXTRA_ROWS = {
  lastActive: { email: 'tc019-last-active@example.test', role: 'care_coordinator', status: 'active', full_name: 'Fictional Lee Lastrow' },
  deactivated: { email: 'tc019-deactivated@example.test', role: 'read_only', status: 'deactivated', full_name: 'Fictional Kim Deactivated' },
} as const;

// Ensures the F1 extra rows exist, re-asserts their status, and orders the
// tail of the table: lastActive, deactivated, invited, then --last on top.
async function ensureTail(creds: Creds): Promise<void> {
  for (const key of ['lastActive', 'deactivated'] as const) {
    const spec = EXTRA_ROWS[key];
    const userId = (await findUserId(spec.email)) ?? (await createUser(spec.email, genPassword()));
    creds[key] = { email: spec.email, userId };
  }
  const now = Date.now();
  const at = (offsetMs: number) => new Date(now + offsetMs).toISOString();
  const order: Record<LastKey, number> = { lastActive: -120_000, deactivated: -60_000, invited: 0 };
  order[LAST] = 60_000;
  for (const key of ['lastActive', 'deactivated'] as const) {
    const spec = EXTRA_ROWS[key];
    await upsertMember({
      user_id: creds[key]!.userId,
      org_id: creds.orgId,
      role: spec.role,
      status: spec.status,
      full_name: spec.full_name,
      created_at: at(order[key]),
    });
  }
  await upsertMember({
    user_id: creds.invited.userId,
    org_id: creds.orgId,
    role: 'physician',
    status: 'invited',
    full_name: 'Fictional Taylor Invitee',
    created_at: at(order.invited),
  });
  writeFileSync(CREDS_PATH, JSON.stringify(creds), { mode: 0o600 });
  chmodSync(CREDS_PATH, 0o600);
}

async function stillValid(creds: Creds): Promise<boolean> {
  try {
    for (const u of [creds.orgAdmin, creds.physician, creds.coordinator, creds.readOnly, creds.invited]) {
      const id = await findUserId(u.email);
      if (id !== u.userId) return false;
    }
    return true;
  } catch {
    return false;
  }
}

async function upsertMember(params: {
  user_id: string;
  org_id: string;
  role: string;
  status: string;
  full_name: string;
  created_at?: string;
}) {
  await restUpsert('org_members', params, 'user_id');
}

async function main() {
  if (existsSync(CREDS_PATH)) {
    const existing = JSON.parse(readFileSync(CREDS_PATH, 'utf8')) as Creds;
    if (await stillValid(existing)) {
      // Keep the invite fresh ("N days left") and re-assert roles/status in
      // case a previous browser-check run changed one (e.g. a role-change
      // confirm click actually went through).
      await upsertMember({
        user_id: existing.orgAdmin.userId,
        org_id: existing.orgId,
        role: 'org_admin',
        status: 'active',
        full_name: 'Fictional Org Admin',
      });
      await upsertMember({
        user_id: existing.physician.userId,
        org_id: existing.orgId,
        role: 'physician',
        status: 'active',
        full_name: 'Fictional Dana Physician',
      });
      await upsertMember({
        user_id: existing.coordinator.userId,
        org_id: existing.orgId,
        role: 'care_coordinator',
        status: 'active',
        full_name: 'Fictional Sam Coordinator',
      });
      await upsertMember({
        user_id: existing.readOnly.userId,
        org_id: existing.orgId,
        role: 'read_only',
        status: 'active',
        full_name: 'Fictional Robin Readonly',
      });
      await upsertMember({
        user_id: existing.invited.userId,
        org_id: existing.orgId,
        role: 'physician',
        status: 'invited',
        full_name: 'Fictional Taylor Invitee',
        created_at: new Date().toISOString(),
      });
      await ensureTail(existing);
      console.log(JSON.stringify({ reused: true, orgId: existing.orgId, last: LAST }));
      return;
    }
  }

  const orgRows = await rest('organizations', { name: 'TC-019 Care Team (fictional)' });
  const orgId = orgRows[0].id as string;

  const orgAdminEmail = 'tc019-orgadmin@example.test';
  const orgAdminPassword = genPassword();
  const orgAdminId = await createUser(orgAdminEmail, orgAdminPassword);
  await upsertMember({ user_id: orgAdminId, org_id: orgId, role: 'org_admin', status: 'active', full_name: 'Fictional Org Admin' });
  const orgAdminSecret = await enrolTotp(orgAdminEmail, orgAdminPassword);

  const physicianEmail = 'tc019-physician@example.test';
  const physicianPassword = genPassword();
  const physicianId = await createUser(physicianEmail, physicianPassword);
  await upsertMember({ user_id: physicianId, org_id: orgId, role: 'physician', status: 'active', full_name: 'Fictional Dana Physician' });
  const physicianSecret = await enrolTotp(physicianEmail, physicianPassword);

  const coordinatorEmail = 'tc019-coordinator@example.test';
  const coordinatorId = await createUser(coordinatorEmail, genPassword());
  await upsertMember({ user_id: coordinatorId, org_id: orgId, role: 'care_coordinator', status: 'active', full_name: 'Fictional Sam Coordinator' });

  const readOnlyEmail = 'tc019-readonly@example.test';
  const readOnlyId = await createUser(readOnlyEmail, genPassword());
  await upsertMember({ user_id: readOnlyId, org_id: orgId, role: 'read_only', status: 'active', full_name: 'Fictional Robin Readonly' });

  const invitedEmail = 'tc019-invited@example.test';
  const invitedId = await createUser(invitedEmail, genPassword());
  await upsertMember({
    user_id: invitedId,
    org_id: orgId,
    role: 'physician',
    status: 'invited',
    full_name: 'Fictional Taylor Invitee',
    created_at: new Date().toISOString(),
  });

  const creds: Creds = {
    orgId,
    orgAdmin: { email: orgAdminEmail, password: orgAdminPassword, totpSecret: orgAdminSecret, userId: orgAdminId },
    physician: { email: physicianEmail, password: physicianPassword, totpSecret: physicianSecret, userId: physicianId },
    coordinator: { email: coordinatorEmail, userId: coordinatorId },
    readOnly: { email: readOnlyEmail, userId: readOnlyId },
    invited: { email: invitedEmail, userId: invitedId },
  };
  await ensureTail(creds);
  console.log(JSON.stringify({ reused: false, orgId, last: LAST }));
}

main().catch((err) => {
  console.error(String(err?.stack ?? err));
  process.exit(1);
});
