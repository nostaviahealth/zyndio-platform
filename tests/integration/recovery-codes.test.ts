// OVERRIDES #3 + Henry's #10: a recovery code is one-time use; consuming one
// flags the account for mandatory re-enrollment, and recovery-reenrol (an
// Edge Function, service role) removes the TOTP factor so the person must
// scan -> verify -> get new codes. New codes invalidate all previous ones.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL } from './setup';
import { adminFetch, createUser, deleteUser, enrollAndVerifyTotp, signIn } from './helpers';

async function generateCodes(aal2Token: string): Promise<string[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/generate_recovery_codes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal2Token}` },
    body: '{}',
  });
  return (await res.json()) as string[];
}

async function consumeCode(aal1Token: string, code: string) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/consume_recovery_code`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal1Token}` },
    body: JSON.stringify({ p_code: code }),
  });
  return { status: res.status, body: (await res.json()) as { status?: string; must_reenrol?: boolean } };
}

function reenrol(token: string) {
  return fetch(`${SUPABASE_FUNCTIONS_URL}/recovery-reenrol`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
  });
}

describe.skipIf(!integrationEnvReady)('recovery-codes', () => {
  it('a code is one-time use, flags re-enrollment, and recovery-reenrol removes the TOTP factor', async () => {
    const user = await createUser('tc005-recovery');
    try {
      const aal1 = await signIn(user.email, user.password);
      const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
      const codes = await generateCodes(aal2Token!);
      expect(codes).toHaveLength(10);

      const freshAal1 = await signIn(user.email, user.password);
      const first = await consumeCode(freshAal1.access_token!, codes[0]);
      expect(first.body.status).toBe('ok');
      expect(first.body.must_reenrol).toBe(true);

      // Same code again -> rejected (one-time use).
      const freshAal1Again = await signIn(user.email, user.password);
      const reused = await consumeCode(freshAal1Again.access_token!, codes[0]);
      expect(reused.body.status).not.toBe('ok');

      const reenrolRes = await reenrol(freshAal1.access_token!);
      const reenrolBody = (await reenrolRes.json()) as { reenrollment_required: boolean };
      expect(reenrolRes.status).toBe(200);
      expect(reenrolBody.reenrollment_required).toBe(true);

      const userRes = await adminFetch(`admin/users/${user.userId}`);
      const userBody = (await userRes.json()) as { factors?: unknown[] };
      expect(userBody.factors ?? []).toHaveLength(0);
    } finally {
      await deleteUser(user.userId);
    }
  });

  it('generating new codes invalidates all previous codes', async () => {
    const user = await createUser('tc005-recovery-rotate');
    try {
      const aal1 = await signIn(user.email, user.password);
      const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
      const firstBatch = await generateCodes(aal2Token!);
      const secondBatch = await generateCodes(aal2Token!);
      expect(secondBatch).toHaveLength(10);
      expect(secondBatch[0]).not.toBe(firstBatch[0]);

      const freshAal1 = await signIn(user.email, user.password);
      const usingOldCode = await consumeCode(freshAal1.access_token!, firstBatch[0]);
      expect(usingOldCode.body.status).not.toBe('ok');
    } finally {
      await deleteUser(user.userId);
    }
  });

  it('recovery-reenrol is a no-op when no re-enrollment is pending', async () => {
    const user = await createUser('tc005-recovery-noop');
    try {
      const aal1 = await signIn(user.email, user.password);
      const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
      const res = await reenrol(aal2Token!);
      const body = (await res.json()) as { reenrollment_required: boolean };
      expect(res.status).toBe(200);
      expect(body.reenrollment_required).toBe(false);

      const userRes = await adminFetch(`admin/users/${user.userId}`);
      const userBody = (await userRes.json()) as { factors?: unknown[] };
      expect(userBody.factors ?? []).toHaveLength(1);
    } finally {
      await deleteUser(user.userId);
    }
  });
});
