// Shared fetch/TOTP helpers for tests/integration/*.test.ts, factored out of
// scripts/tc005-auth-hooks-live-check.ts and scripts/tc005-edge-live-check.ts
// (step 2/3's manual live checks - this is those checks turned into real,
// repeatable tests). Local Supabase + local `supabase functions serve` only.
import crypto from 'node:crypto';
import { SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_FUNCTIONS_URL } from './setup';

export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('not a JWT');
  const payload = Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
  return JSON.parse(payload);
}

// Normalizes volatile fields (timestamps, request ids) so two otherwise
// byte-identical GoTrue bodies compare equal.
export function normalizeBody(body: string): string {
  return body
    .replace(/"error_id":"[^"]*"/g, '"error_id":"<normalized>"')
    .replace(/\d{4}-\d{2}-\d{2}T[\d:.]+Z/g, '<normalized-timestamp>');
}

function base32Decode(input: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const char of input.toUpperCase().replace(/=+$/, '')) {
    const idx = alphabet.indexOf(char);
    if (idx === -1) continue;
    bits += idx.toString(2).padStart(5, '0');
  }
  const bytes: number[] = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
  return Buffer.from(bytes);
}

// Minimal RFC 6238 TOTP so tests can complete real enroll/verify round-trips
// against local GoTrue without an extra dependency.
export function totpCode(base32Secret: string, atMs = Date.now()): string {
  const key = base32Decode(base32Secret);
  const counter = Math.floor(atMs / 1000 / 30);
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter));
  const hmac = crypto.createHmac('sha1', key).update(counterBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const binCode =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return (binCode % 1_000_000).toString().padStart(6, '0');
}

export const FICTIONAL_PASSWORD = 'Correct-Horse-Battery-99!';

export function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

export function adminFetch(path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}/auth/v1/${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      ...init.headers,
    },
  });
}

export function restAdmin(path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      Prefer: 'return=representation',
      ...init.headers,
    },
  });
}

export function anonSignIn(email: string, password: string) {
  return fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
    body: JSON.stringify({ email, password }),
  });
}

export async function signIn(email: string, password: string) {
  const res = await anonSignIn(email, password);
  return (await res.json()) as { access_token?: string; refresh_token?: string };
}

export function recoverRequest(email: string) {
  return fetch(`${SUPABASE_URL}/auth/v1/recover`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
    body: JSON.stringify({ email }),
  });
}

export function callFn(name: string, token: string, body?: unknown) {
  return fetch(`${SUPABASE_FUNCTIONS_URL}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export async function createUser(emailPrefix: string, password = FICTIONAL_PASSWORD) {
  const email = `${emailPrefix}-${uniqueSuffix()}@example.test`;
  const res = await adminFetch('admin/users', {
    method: 'POST',
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  const created = (await res.json()) as { id: string };
  return { userId: created.id, email, password };
}

export async function createOrgAndMember(role: string, status = 'active', orgId?: string) {
  const { userId, email, password } = await createUser(`tc005-${role}`);

  let org_id = orgId;
  if (!org_id) {
    const orgRes = await restAdmin('organizations', {
      method: 'POST',
      body: JSON.stringify({ name: `Integration test org ${uniqueSuffix()}` }),
    });
    const [org] = (await orgRes.json()) as { id: string }[];
    org_id = org.id;
  }

  await restAdmin('org_members', {
    method: 'POST',
    body: JSON.stringify({ user_id: userId, org_id, role, status }),
  });

  return { userId, orgId: org_id, email, password };
}

// Enrolls + verifies a TOTP factor for an aal1 session, returning the
// resulting aal2 access token and the factor's base32 secret.
export async function enrollAndVerifyTotp(aal1Token: string) {
  const enrollRes = await fetch(`${SUPABASE_URL}/auth/v1/factors`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal1Token}` },
    body: JSON.stringify({ factor_type: 'totp' }),
  });
  const enrolled = (await enrollRes.json()) as { id: string; totp: { secret: string } };

  const challengeRes = await fetch(`${SUPABASE_URL}/auth/v1/factors/${enrolled.id}/challenge`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal1Token}` },
  });
  const challenge = (await challengeRes.json()) as { id: string };

  const code = totpCode(enrolled.totp.secret);
  const verifyRes = await fetch(`${SUPABASE_URL}/auth/v1/factors/${enrolled.id}/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal1Token}` },
    body: JSON.stringify({ challenge_id: challenge.id, code }),
  });
  const verified = (await verifyRes.json()) as { access_token?: string };
  return { aal2Token: verified.access_token, factorId: enrolled.id, secret: enrolled.totp.secret };
}

export function mfaVerify(factorId: string, challengeId: string, code: string, token: string) {
  return fetch(`${SUPABASE_URL}/auth/v1/factors/${factorId}/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
    body: JSON.stringify({ challenge_id: challengeId, code }),
  });
}

export function mfaChallenge(factorId: string, token: string) {
  return fetch(`${SUPABASE_URL}/auth/v1/factors/${factorId}/challenge`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
  });
}

export async function deleteUser(userId: string) {
  await adminFetch(`admin/users/${userId}`, { method: 'DELETE' });
}

export async function auditRows(eventType: string, targetUserId: string) {
  const res = await restAdmin(`audit_log?event_type=eq.${eventType}&target_user_id=eq.${targetUserId}`);
  return (await res.json()) as unknown[];
}
