// Plan section B / OVERRIDES: 5 wrong attempts locks the account for 15
// minutes, on one shared counter across password, TOTP and recovery-code
// attempts (public.bump_wrong_attempt via supabase/migrations/...auth_hooks.sql).
import { describe, it, expect, afterEach } from 'vitest';
import { integrationEnvReady } from './setup';
import {
  anonSignIn,
  createUser,
  deleteUser,
  enrollAndVerifyTotp,
  mfaChallenge,
  mfaVerify,
  restAdmin,
  signIn,
} from './helpers';

describe.skipIf(!integrationEnvReady)('lockout', () => {
  const cleanup: string[] = [];
  afterEach(async () => {
    while (cleanup.length) await deleteUser(cleanup.pop()!);
  });

  it('5 wrong passwords lock the account; a subsequent correct password is rejected as locked', async () => {
    const user = await createUser('tc005-lockout-pw');
    cleanup.push(user.userId);

    for (let i = 0; i < 5; i++) {
      const res = await anonSignIn(user.email, 'definitely-wrong-password');
      expect(res.status).not.toBe(200);
    }

    const correctWhileLocked = await anonSignIn(user.email, user.password);
    const body = (await correctWhileLocked.json()) as { msg?: string };
    expect(correctWhileLocked.status).not.toBe(200);
    expect(body.msg).toBe('locked');

    const stateRes = await restAdmin(`auth_attempt_state?user_id=eq.${user.userId}&select=wrong_count,locked_until`);
    const [state] = (await stateRes.json()) as { wrong_count: number; locked_until: string }[];
    expect(state.wrong_count).toBeGreaterThanOrEqual(5);
    const lockDurationMs = new Date(state.locked_until).getTime() - Date.now();
    // ~15 minutes, generous bounds for test-run latency.
    expect(lockDurationMs).toBeGreaterThan(13 * 60 * 1000);
    expect(lockDurationMs).toBeLessThan(16 * 60 * 1000);
  });

  it('5 wrong TOTP codes lock the account, and the lock is shared with password sign-in', async () => {
    const user = await createUser('tc005-lockout-totp');
    cleanup.push(user.userId);

    const aal1 = await signIn(user.email, user.password);
    const { factorId } = await enrollAndVerifyTotp(aal1.access_token!);

    const freshAal1 = await signIn(user.email, user.password);
    for (let i = 0; i < 5; i++) {
      const challenge = (await (await mfaChallenge(factorId, freshAal1.access_token!)).json()) as { id: string };
      const res = await mfaVerify(factorId, challenge.id, '000000', freshAal1.access_token!);
      expect(res.status).not.toBe(200);
    }

    const correctPasswordWhileLocked = await anonSignIn(user.email, user.password);
    const body = (await correctPasswordWhileLocked.json()) as { msg?: string };
    expect(body.msg).toBe('locked');
  });

  it('5 wrong recovery codes lock the account via the same shared counter', async () => {
    const user = await createUser('tc005-lockout-recovery');
    cleanup.push(user.userId);

    const aal1 = await signIn(user.email, user.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const codesRes = await fetch(`${process.env.SUPABASE_URL}/rest/v1/rpc/generate_recovery_codes`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: process.env.SUPABASE_ANON_KEY!,
        Authorization: `Bearer ${aal2Token}`,
      },
      body: '{}',
    });
    expect(codesRes.status).toBe(200);

    const freshAal1 = await signIn(user.email, user.password);
    for (let i = 0; i < 5; i++) {
      const res = await fetch(`${process.env.SUPABASE_URL}/rest/v1/rpc/consume_recovery_code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: process.env.SUPABASE_ANON_KEY!,
          Authorization: `Bearer ${freshAal1.access_token}`,
        },
        body: JSON.stringify({ p_code: 'ZZZZZZZZZZWRONGCODE' }),
      });
      const body = (await res.json()) as { status?: string };
      expect(body.status).not.toBe('ok');
    }

    const correctPasswordWhileLocked = await anonSignIn(user.email, user.password);
    const body = (await correctPasswordWhileLocked.json()) as { msg?: string };
    expect(body.msg).toBe('locked');
  });
});
