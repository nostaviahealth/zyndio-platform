// TC-021 item 23 (Henry): the intelligence function answers 400 with a
// GENERIC message when the body is not valid JSON or is JSON null - never a
// 500, and never the JSON parser's own text. Auth/role checks still come
// first: a non-patient with a broken body gets 403, not 400.
// Raw fetch (not callFn) so the body can be malformed. Fictional data only.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL } from './setup';
import { createOrgAndMember, createUser, deleteUser, seedSelfSignupPatient, signIn } from './helpers';

function post(token: string, rawBody: string | undefined) {
  return fetch(`${SUPABASE_FUNCTIONS_URL}/intelligence`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
    body: rawBody,
  });
}

const PARSER_TEXT = /JSON|Unexpected|token|position|destructure|null|Cannot/i;

describe.skipIf(!integrationEnvReady)('intelligence rejects bad bodies with a generic 400 (TC-021 #23)', () => {
  async function asPatient<T>(fn: (token: string) => Promise<T>) {
    const user = await createUser('tc021-i23');
    await seedSelfSignupPatient(user.userId);
    try {
      const session = await signIn(user.email, user.password);
      return await fn(session.access_token!);
    } finally {
      await deleteUser(user.userId);
    }
  }

  const cases: Array<[string, string | undefined]> = [
    ['invalid JSON', '{"messages": [ {"role": "user", '],
    ['the JSON literal null', 'null'],
    ['an empty body', ''],
  ];

  for (const [label, raw] of cases) {
    it(`answers 400 with a generic message to ${label}`, async () => {
      await asPatient(async (token) => {
        const res = await post(token, raw);
        const text = await res.text();
        expect(res.status, `body: ${text}`).toBe(400);
        const body = JSON.parse(text) as { error?: string };
        expect(body).toEqual({ error: 'invalid request body' });
        expect(text).not.toMatch(PARSER_TEXT);
      });
    });
  }

  it('still checks the role first: the anon key with invalid JSON gets 403', async () => {
    const res = await post(SUPABASE_ANON_KEY!, '{not json');
    await res.text();
    expect(res.status).toBe(403);
  });

  it('still checks the role first: a staff member with invalid JSON gets 403', async () => {
    const member = await createOrgAndMember('physician');
    try {
      const session = await signIn(member.email, member.password);
      const res = await post(session.access_token!, '{not json');
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(403);
      expect(body.error).toBe('intelligence_patients_only');
    } finally {
      await deleteUser(member.userId);
    }
  });

  it('a valid body still reaches body validation (400 messages array is required)', async () => {
    await asPatient(async (token) => {
      const res = await post(token, '{}');
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(400);
      expect(body.error).toBe('messages array is required');
    });
  });
});
