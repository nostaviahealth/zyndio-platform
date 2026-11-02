import { assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import {
  consumeIntelligenceBudget,
  INTELLIGENCE_DAILY_LIMIT,
  INTELLIGENCE_HOURLY_LIMIT,
  rateLimitedHeaders,
} from './intelligenceRateLimit.ts'
import { sha256Hex } from './clientIp.ts'

const PATIENT = '33333333-3333-4333-8333-333333333333'

function fakeRpc(result: { data: unknown; error: unknown }, seen: unknown[] = []): SupabaseClient {
  const fake = {
    rpc(name: string, args: unknown) {
      seen.push({ name, args })
      return Promise.resolve(result)
    },
  }
  return fake as unknown as SupabaseClient
}

Deno.test('intelligence budget: calls the RPC with the hashed patient id and the fixed hour/day budgets', async () => {
  const seen: unknown[] = []
  const res = await consumeIntelligenceBudget(fakeRpc({ data: [{ allowed: true, retry_after_seconds: 0 }], error: null }, seen), PATIENT)
  assertEquals(res, { allowed: true })
  assertEquals(seen, [{
    name: 'consume_intelligence_budget',
    args: { p_key_hash: await sha256Hex(PATIENT), p_hour_limit: INTELLIGENCE_HOURLY_LIMIT, p_day_limit: INTELLIGENCE_DAILY_LIMIT },
  }])
  assertEquals([INTELLIGENCE_HOURLY_LIMIT, INTELLIGENCE_DAILY_LIMIT], [30, 200])
})

Deno.test('intelligence budget: over budget returns the Retry-After seconds', async () => {
  const res = await consumeIntelligenceBudget(fakeRpc({ data: [{ allowed: false, retry_after_seconds: 1234 }], error: null }), PATIENT)
  assertEquals(res, { allowed: false, retryAfterSeconds: 1234 })
})

Deno.test('intelligence budget: a missing/zero Retry-After is at least 1 second', async () => {
  const res = await consumeIntelligenceBudget(fakeRpc({ data: [{ allowed: false, retry_after_seconds: null }], error: null }), PATIENT)
  assertEquals(res, { allowed: false, retryAfterSeconds: 1 })
})

Deno.test('intelligence budget: an RPC error throws (fail closed)', async () => {
  await assertRejects(() => consumeIntelligenceBudget(fakeRpc({ data: null, error: { message: 'boom' } }), PATIENT))
})

Deno.test('intelligence budget: an unexpected result throws (fail closed)', async () => {
  await assertRejects(() => consumeIntelligenceBudget(fakeRpc({ data: [], error: null }), PATIENT))
})

Deno.test('intelligence budget: 429 headers carry Retry-After and expose it to the browser', () => {
  assertEquals(rateLimitedHeaders(42), { 'Retry-After': '42', 'Access-Control-Expose-Headers': 'Retry-After' })
})
