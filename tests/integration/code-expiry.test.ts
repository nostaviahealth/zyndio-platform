// Plan section B: an MFA challenge presented more than 10 minutes after the
// password was verified is rejected, even with a correct code. Time is
// simulated by updating auth_attempt_state as service role / SQL - never by
// sleeping 10 minutes.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady } from './setup';
import { createUser, deleteUser, enrollAndVerifyTotp, mfaChallenge, mfaVerify, restAdmin, signIn, totpCode } from './helpers';

describe.skipIf(!integrationEnvReady)('code-expiry', () => {
  it('rejects a correct TOTP code once password_verified_at is more than 10 minutes old', async () => {
    const user = await createUser('tc005-expiry');
    try {
      const aal1 = await signIn(user.email, user.password);
      const { factorId, secret } = await enrollAndVerifyTotp(aal1.access_token!);

      // Fresh sign-in sets password_verified_at = now(); push it back past
      // the 10-minute window directly in the DB.
      const freshAal1 = await signIn(user.email, user.password);
      const patchRes = await restAdmin(`auth_attempt_state?user_id=eq.${user.userId}`, {
        method: 'PATCH',
        body: JSON.stringify({ password_verified_at: new Date(Date.now() - 11 * 60 * 1000).toISOString() }),
      });
      expect(patchRes.ok).toBe(true);

      const challenge = (await (await mfaChallenge(factorId, freshAal1.access_token!)).json()) as { id: string };
      const verifyRes = await mfaVerify(factorId, challenge.id, totpCode(secret), freshAal1.access_token!);
      const verifyBody = (await verifyRes.json()) as { msg?: string };

      expect(verifyRes.status).not.toBe(200);
      expect(verifyBody.msg).toBe('challenge_expired');
    } finally {
      await deleteUser(user.userId);
    }
  });

  it('accepts a correct TOTP code within the 10-minute window', async () => {
    const user = await createUser('tc005-expiry-ok');
    try {
      const aal1 = await signIn(user.email, user.password);
      const { factorId, secret } = await enrollAndVerifyTotp(aal1.access_token!);

      const freshAal1 = await signIn(user.email, user.password);
      const challenge = (await (await mfaChallenge(factorId, freshAal1.access_token!)).json()) as { id: string };
      const verifyRes = await mfaVerify(factorId, challenge.id, totpCode(secret), freshAal1.access_token!);
      expect(verifyRes.status).toBe(200);
    } finally {
      await deleteUser(user.userId);
    }
  });
});
