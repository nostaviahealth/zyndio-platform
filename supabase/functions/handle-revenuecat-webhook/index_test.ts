import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { handleRevenueCatWebhook } from './index.ts'

// Fictional patient ids (RevenueCat app_user_id = the patient's auth uid).
const USER_1 = '00000000-0000-0000-0000-00000000c001'
const USER_9 = '00000000-0000-0000-0000-00000000c009'

const NOW = Date.parse('2026-11-08T12:00:00Z')
const DAY = 24 * 60 * 60 * 1000

function event(fields: Record<string, unknown>): string {
  return JSON.stringify({
    event: {
      id: 'evt-purchase-1',
      type: 'INITIAL_PURCHASE',
      app_user_id: USER_1,
      entitlement_ids: ['Zyndio Plus'],
      event_timestamp_ms: NOW - DAY,
      expiration_at_ms: NOW + 30 * DAY,
      ...fields,
    },
  })
}

const VALID_BODY = event({})

function req(body: string, authHeader: string | null): Request {
  const headers = new Headers({ 'content-type': 'application/json' })
  if (authHeader !== null) headers.set('Authorization', authHeader)
  return new Request('https://example.test/handle-revenuecat-webhook', { method: 'POST', headers, body })
}

function fakeEnv(vars: Record<string, string>) {
  return { get: (key: string) => vars[key] }
}

type Account = { is_premium: boolean; subscription_plan: string; subscription_expires_at: string | null; event_at: string }

// Minimal stand-in for public.apply_revenuecat_event (pgTAP 771 proves the
// real one): `calls` records RPC names; `store` is patient_accounts keyed by
// patient_id; `events` the recorded event ids. Same rules as the SQL: repeat id
// -> 'duplicate'; older than the stored event -> 'stale'; else upsert.
function clientFactory(
  calls: string[],
  opts: {
    rpcError?: { code?: string; message?: string }
    throws?: boolean
    store?: Map<string, Account>
    events?: Set<string>
  } = {},
) {
  const store = opts.store ?? new Map<string, Account>()
  const events = opts.events ?? new Set<string>()
  return () => ({
    from(table: string) {
      calls.push(`from:${table}`)
      throw new Error('webhook must not write tables directly')
    },
    rpc(name: string, args: Record<string, unknown>) {
      calls.push(name)
      if (opts.throws) throw new Error('network down')
      if (opts.rpcError) return Promise.resolve({ data: null, error: opts.rpcError })
      const id = args.p_event_id as string
      if (events.has(id)) return Promise.resolve({ data: 'duplicate', error: null })
      events.add(id)
      const pid = args.p_patient_id as string
      const current = store.get(pid)
      if (current && current.event_at >= (args.p_event_at as string)) {
        return Promise.resolve({ data: 'stale', error: null })
      }
      const grant = args.p_action === 'grant'
      store.set(pid, {
        is_premium: grant,
        subscription_plan: grant ? 'plus' : 'free',
        subscription_expires_at: (args.p_expires_at as string | null) ?? null,
        event_at: args.p_event_at as string,
      })
      return Promise.resolve({ data: 'applied', error: null })
    },
  }) as any
}

function deps(calls: string[], opts: Parameters<typeof clientFactory>[1] = {}) {
  return {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls, opts),
    now: () => NOW,
  }
}

Deno.test('missing Authorization header -> 401, DB never touched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, null), deps(calls))
  assertEquals(res.status, 401)
  assertEquals(calls.length, 0)
})

Deno.test('wrong Authorization secret -> 401, DB never touched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'not-the-secret'), deps(calls))
  assertEquals(res.status, 401)
  assertEquals(calls.length, 0)
})

Deno.test('unset REVENUECAT_WEBHOOK_AUTH env var -> 401 (fail closed), DB never touched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), {
    env: fakeEnv({}),
    createServiceClient: clientFactory(calls),
  })
  assertEquals(res.status, 401)
  assertEquals(calls.length, 0)
})

Deno.test('correct secret -> accepted, goes through apply_revenuecat_event (never profiles or a raw table write)', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps(calls))
  assertEquals(res.status, 200)
  assertEquals(calls, ['apply_revenuecat_event'])
})

// TC-030 item 2 (Clara PR #25 M2): a purchase for a patient with no row creates
// the row with premium set (the old `.update().eq()` wrote 0 rows).
Deno.test('M2: INITIAL_PURCHASE for a patient with no row -> row is created with premium', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps(calls, { store }))
  assertEquals(res.status, 200)
  assertEquals(store.get(USER_1)?.is_premium, true)
  assertEquals(store.get(USER_1)?.subscription_plan, 'plus')
  assertEquals(store.get(USER_1)?.subscription_expires_at, new Date(NOW + 30 * DAY).toISOString())
})

// A genuine DB failure must surface as a 5xx so RevenueCat retries.
Deno.test('M2: a real DB write failure -> 5xx so RevenueCat retries', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps(calls, { rpcError: { code: '40001', message: 'boom' } }))
  assertEquals(res.status >= 500, true)
})

// A crash used to return 200, so RevenueCat never retried and the event was lost.
Deno.test('a crash while processing -> 5xx so RevenueCat retries (was 200)', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps(calls, { throws: true }))
  assertEquals(res.status, 500)
})

Deno.test('M2: replaying the same event is idempotent (same end state, no error)', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const d = deps(calls, { store })
  const first = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), d)
  const second = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), d)
  assertEquals(first.status, 200)
  assertEquals(second.status, 200)
  assertEquals((await second.json()).outcome, 'duplicate')
  assertEquals(store.size, 1)
  assertEquals(store.get(USER_1)?.is_premium, true)
  assertEquals(store.get(USER_1)?.subscription_plan, 'plus')
})

Deno.test('M2: EXPIRATION for a patient with no row -> row created as free', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const body = event({ id: 'evt-exp-9', type: 'EXPIRATION', app_user_id: USER_9, entitlement_ids: [], expiration_at_ms: NOW - DAY })
  const res = await handleRevenueCatWebhook(req(body, 'the-secret'), deps(calls, { store }))
  assertEquals(res.status, 200)
  assertEquals(store.get(USER_9)?.is_premium, false)
  assertEquals(store.get(USER_9)?.subscription_plan, 'free')
})

// RevenueCat's EXPIRATION lists the entitlement that expired. The old code saw
// 'Zyndio Plus' in entitlement_ids and kept the patient premium forever.
Deno.test('EXPIRATION that still lists the entitlement -> downgraded to free', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const d = deps(calls, { store })
  await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), d)
  const exp = event({ id: 'evt-exp-1', type: 'EXPIRATION', event_timestamp_ms: NOW, expiration_at_ms: NOW - 1000 })
  const res = await handleRevenueCatWebhook(req(exp, 'the-secret'), d)
  assertEquals(res.status, 200)
  assertEquals(store.get(USER_1)?.is_premium, false)
})

// CANCELLATION = auto-renew off: access continues until the paid period ends.
Deno.test('CANCELLATION before expiry keeps premium until the period ends', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const d = deps(calls, { store })
  await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), d)
  const cancel = event({ id: 'evt-cancel-1', type: 'CANCELLATION', event_timestamp_ms: NOW, expiration_at_ms: NOW + 10 * DAY })
  await handleRevenueCatWebhook(req(cancel, 'the-secret'), d)
  assertEquals(store.get(USER_1)?.is_premium, true)
  assertEquals(store.get(USER_1)?.subscription_expires_at, new Date(NOW + 10 * DAY).toISOString())
})

Deno.test('refund-style CANCELLATION (expiry already past) -> free', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const d = deps(calls, { store })
  await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), d)
  const refund = event({ id: 'evt-refund-1', type: 'CANCELLATION', event_timestamp_ms: NOW, expiration_at_ms: NOW - 1000 })
  await handleRevenueCatWebhook(req(refund, 'the-secret'), d)
  assertEquals(store.get(USER_1)?.is_premium, false)
})

// Out-of-order delivery: a delayed, older EXPIRATION must not downgrade a
// patient whose newer RENEWAL was already applied.
Deno.test('an older EXPIRATION arriving after a newer RENEWAL changes nothing', async () => {
  const calls: string[] = []
  const store = new Map<string, Account>()
  const d = deps(calls, { store })
  const renewal = event({ id: 'evt-renew-2', type: 'RENEWAL', event_timestamp_ms: NOW, expiration_at_ms: NOW + 30 * DAY })
  const lateExpiry = event({ id: 'evt-exp-old', type: 'EXPIRATION', event_timestamp_ms: NOW - 2 * DAY, expiration_at_ms: NOW - 2 * DAY })
  await handleRevenueCatWebhook(req(renewal, 'the-secret'), d)
  const res = await handleRevenueCatWebhook(req(lateExpiry, 'the-secret'), d)
  assertEquals(res.status, 200)
  assertEquals((await res.json()).outcome, 'stale')
  assertEquals(store.get(USER_1)?.is_premium, true)
})

Deno.test('TEST events, anonymous ids and payloads without an event id are acknowledged, DB untouched', async () => {
  for (const body of [
    event({ type: 'TEST' }),
    event({ app_user_id: '$RCAnonymousID:8f0c2b1e' }),
    event({ id: undefined }),
    event({ event_timestamp_ms: undefined }),
    JSON.stringify({ event: { type: 'TRANSFER', transferred_from: [USER_1], transferred_to: [USER_9] } }),
  ]) {
    const calls: string[] = []
    const res = await handleRevenueCatWebhook(req(body, 'the-secret'), deps(calls))
    assertEquals(res.status, 200)
    assertEquals(calls.length, 0)
  }
})

Deno.test('event for a user who is not a patient (FK violation) is acknowledged, not retried forever', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps(calls, { rpcError: { code: '23503' } }))
  assertEquals(res.status, 200)
})

Deno.test('invalid JSON -> 400, DB untouched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req('{nope', 'the-secret'), deps(calls))
  assertEquals(res.status, 400)
  assertEquals(calls.length, 0)
})
