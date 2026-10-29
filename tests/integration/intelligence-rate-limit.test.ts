// TC-021 item 12: per-patient rate limit on the intelligence function - a
// fixed budget per hour and per day. Over budget is 429 with Retry-After
// (seconds until the hour window resets), before any call to the AI
// provider. The budget is per patient: another patient is unaffected.
//
// The hourly budget is INTELLIGENCE_HOURLY_LIMIT (30) in
// supabase/functions/_shared/intelligenceRateLimit.ts; the daily budget
// (200) is covered by pgTAP 725 with small limits.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady } from './setup';
import { callFn, createUser, deleteUser, seedSelfSignupPatient, signIn } from './helpers';

const HOURLY_LIMIT = 30;
const goodBody = { messages: [{ role: 'user', content: 'Summarise my last result, please.' }] };

describe.skipIf(!integrationEnvReady)('intelligence per-patient rate limit (TC-021 #12)', () => {
  it('answers 429 with Retry-After once the hourly budget is spent, per patient', async () => {
    const a = await createUser('tc021-intel-rl-a');
    const b = await createUser('tc021-intel-rl-b');
    await seedSelfSignupPatient(a.userId);
    await seedSelfSignupPatient(b.userId);
    try {
      const tokenA = (await signIn(a.email, a.password)).access_token!;
      for (let i = 1; i <= HOURLY_LIMIT; i += 1) {
        const res = await callFn('intelligence', tokenA, goodBody);
        await res.text();
        // Within budget: never a 429 (CI has no AI key, so these end at the
        // provider step with 500 'AI service not configured').
        expect(res.status, `call ${i} is within the hourly budget`).not.toBe(429);
      }

      const over = await callFn('intelligence', tokenA, goodBody);
      const overBody = (await over.json()) as { error?: string };
      expect(over.status).toBe(429);
      expect(overBody.error).toBe('rate_limited');
      const retryAfter = Number(over.headers.get('Retry-After'));
      expect(Number.isInteger(retryAfter)).toBe(true);
      expect(retryAfter).toBeGreaterThanOrEqual(1);
      expect(retryAfter).toBeLessThanOrEqual(3600);
      expect((over.headers.get('Access-Control-Expose-Headers') ?? '').toLowerCase()).toContain('retry-after');

      // Patient B has their own budget.
      const tokenB = (await signIn(b.email, b.password)).access_token!;
      const resB = await callFn('intelligence', tokenB, goodBody);
      await resB.text();
      expect(resB.status).not.toBe(429);
    } finally {
      await deleteUser(a.userId);
      await deleteUser(b.userId);
    }
  });
});
