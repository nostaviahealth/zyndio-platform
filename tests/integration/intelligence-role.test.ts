// TC-022 item 4 (Clara, PR #11 review): the intelligence function must check
// the caller's role BEFORE it validates the request body, so a caller with
// the wrong role (the bare anon key, or the service-role key, instead of a
// signed-in user's token) gets 403 - never a 400 that reveals the body shape,
// and never a call through to the AI provider.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from './setup';
import { callFn, createUser, deleteUser, signIn } from './helpers';

describe.skipIf(!integrationEnvReady)('intelligence role check (TC-022 #4)', () => {
  it('answers 403 to the anon key with an invalid body (role checked first)', async () => {
    const res = await callFn('intelligence', SUPABASE_ANON_KEY!, {});
    await res.text();
    expect(res.status).toBe(403);
  });

  it('answers 403 to the anon key with a well-formed body too', async () => {
    const res = await callFn('intelligence', SUPABASE_ANON_KEY!, { messages: [{ role: 'user', content: 'hi' }] });
    await res.text();
    expect(res.status).toBe(403);
  });

  it('answers 403 to the service-role key (not a signed-in user)', async () => {
    const res = await callFn('intelligence', SUPABASE_SERVICE_ROLE_KEY!, {});
    await res.text();
    expect(res.status).toBe(403);
  });

  it('still answers 400 to a signed-in user with an invalid body', async () => {
    const user = await createUser('tc022-intel');
    try {
      const session = await signIn(user.email, user.password);
      const res = await callFn('intelligence', session.access_token!, {});
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(400);
      expect(body.error).toBe('messages array is required');
    } finally {
      await deleteUser(user.userId);
    }
  });
});
