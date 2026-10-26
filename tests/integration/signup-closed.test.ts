import { describe, it, expect } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY } from './setup';
import { createUser, signIn, uniqueSuffix, deleteUser } from './helpers';

describe.skipIf(!integrationEnvReady)('signup-closed', () => {
  it('refuses anon self-signup via POST /auth/v1/signup', async () => {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ email: `tc005-signup-${uniqueSuffix()}@example.test`, password: 'Whatever-Pw-123!' }),
    });
    expect([400, 403, 422]).toContain(res.status);
  });

  it('lets an admin-created user sign in with a password', async () => {
    const user = await createUser('tc005-signin');
    try {
      const session = await signIn(user.email, user.password);
      expect(session.access_token).toBeTruthy();
    } finally {
      await deleteUser(user.userId);
    }
  });
});
