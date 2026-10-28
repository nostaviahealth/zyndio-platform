// OVERRIDES #5: sign-in error/network/reset-sent/wrong-password-lockout
// responses must be identical for real and unknown emails; a correct
// password on an already-locked account is the one deliberately
// distinguishable response.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady } from './setup';
import { anonSignIn, createUser, deleteUser, normalizeBody, recoverRequest, uniqueSuffix } from './helpers';

describe.skipIf(!integrationEnvReady)('enumeration-safety', () => {
  it('locked-real + wrong-password is byte-identical to unknown-email + any-password', async () => {
    const user = await createUser('tc005-enum');
    try {
      for (let i = 0; i < 5; i++) {
        await anonSignIn(user.email, 'definitely-wrong-password');
      }
      const lockedWrongRes = await anonSignIn(user.email, 'definitely-wrong-password');
      const lockedWrongBody = normalizeBody(await lockedWrongRes.text());

      const unknownEmail = `tc005-enum-unknown-${uniqueSuffix()}@example.test`;
      const unknownRes = await anonSignIn(unknownEmail, 'definitely-wrong-password');
      const unknownBody = normalizeBody(await unknownRes.text());

      expect(lockedWrongRes.status).toBe(unknownRes.status);
      expect(lockedWrongBody).toBe(unknownBody);

      const lockedCorrectRes = await anonSignIn(user.email, user.password);
      const lockedCorrectBody = normalizeBody(await lockedCorrectRes.text());
      expect(lockedCorrectRes.status !== lockedWrongRes.status || lockedCorrectBody !== lockedWrongBody).toBe(true);
    } finally {
      await deleteUser(user.userId);
    }
  });

  it('a password-reset request is byte-identical for a locked real email and an unknown email', async () => {
    const user = await createUser('tc005-enum-reset');
    try {
      for (let i = 0; i < 5; i++) {
        await anonSignIn(user.email, 'definitely-wrong-password');
      }
      const realRes = await recoverRequest(user.email);
      const realBody = normalizeBody(await realRes.text());

      const unknownEmail = `tc005-enum-reset-unknown-${uniqueSuffix()}@example.test`;
      const unknownRes = await recoverRequest(unknownEmail);
      const unknownBody = normalizeBody(await unknownRes.text());

      expect(realRes.status).toBe(unknownRes.status);
      expect(realBody).toBe(unknownBody);
    } finally {
      await deleteUser(user.userId);
    }
  });
});
