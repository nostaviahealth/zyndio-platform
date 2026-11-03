import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { handleRevenueCatWebhook } from './index.ts'

const VALID_BODY = JSON.stringify({ event: { type: 'INITIAL_PURCHASE', app_user_id: 'user-1', entitlement_ids: ['Zyndio Plus'] } })

function req(body: string, authHeader: string | null): Request {
  const headers = new Headers({ 'content-type': 'application/json' })
  if (authHeader !== null) headers.set('Authorization', authHeader)
  return new Request('https://example.test/handle-revenuecat-webhook', { method: 'POST', headers, body })
}

function fakeEnv(vars: Record<string, string>) {
  return { get: (key: string) => vars[key] }
}

// Minimal stand-in for the PostgREST client's upsert path. `calls` records the
// tables touched; `store` is a tiny patient_accounts keyed by patient_id so an
// upsert creates-or-overwrites exactly like the real table (idempotency), and
// `upsertError` forces a DB failure. `upserts` captures each written row for
// assertions.
function clientFactory(
  calls: string[],
  opts: { upsertError?: unknown; store?: Map<string, Record<string, unknown>>; upserts?: Record<string, unknown>[] } = {},
) {
  const store = opts.store ?? new Map<string, Record<string, unknown>>()
  return () => ({
    from(table: string) {
      calls.push(table)
      return {
        upsert(row: Record<string, unknown>, _options?: Record<string, unknown>) {
          opts.upserts?.push(row)
          if (opts.upsertError === undefined) {
            store.set(row.patient_id as string, { ...store.get(row.patient_id as string), ...row })
          }
          return Promise.resolve({ error: opts.upsertError ?? null })
        },
      }
    },
  }) as any
}

Deno.test('missing Authorization header -> 401, DB never touched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, null), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls),
  })
  assertEquals(res.status, 401)
  assertEquals(calls.length, 0)
})

Deno.test('wrong Authorization secret -> 401, DB never touched', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'not-the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls),
  })
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

Deno.test('correct secret -> accepted, upserts patient_accounts (not profiles)', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls),
  })
  assertEquals(res.status, 200)
  assertEquals(calls, ['patient_accounts'])
})

// TC-030 item 2 (Clara PR #25 M2). Fail-first: the old `.update().eq()` wrote 0
// rows for a patient with no row and still returned 200, so the purchase was
// lost. The upsert now creates the row, so the end state has the premium flag
// set - this assertion fails on the old no-op path.
Deno.test('M2: INITIAL_PURCHASE for a patient with no row -> row is created with premium', async () => {
  const calls: string[] = []
  const store = new Map<string, Record<string, unknown>>()
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls, { store }),
  })
  assertEquals(res.status, 200)
  // The row did not exist before; the upsert created it with premium set.
  assertEquals(store.get('user-1')?.is_premium, true)
  assertEquals(store.get('user-1')?.subscription_plan, 'plus')
})

// Fail-first: a bare UPDATE against a missing row never errors, so the old code
// could only ever return 200. A genuine DB failure must now surface as a 5xx so
// RevenueCat retries instead of dropping the purchase.
Deno.test('M2: a real DB write failure -> 5xx so RevenueCat retries', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls, { upsertError: { message: 'boom' } }),
  })
  assertEquals(res.status >= 500, true)
})

// Idempotency: replaying the same INITIAL_PURCHASE converges on the same end
// state with no error and no duplicate rows.
Deno.test('M2: replaying the same event is idempotent (same end state, no error)', async () => {
  const calls: string[] = []
  const store = new Map<string, Record<string, unknown>>()
  const deps = {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls, { store }),
  }
  const first = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps)
  const second = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), deps)
  assertEquals(first.status, 200)
  assertEquals(second.status, 200)
  assertEquals(store.size, 1)
  assertEquals(store.get('user-1')?.is_premium, true)
  assertEquals(store.get('user-1')?.subscription_plan, 'plus')
})

// An EXPIRATION with no entitlements converges the row to free, idempotently.
Deno.test('M2: EXPIRATION for a patient with no row -> row created as free', async () => {
  const calls: string[] = []
  const store = new Map<string, Record<string, unknown>>()
  const body = JSON.stringify({ event: { type: 'EXPIRATION', app_user_id: 'user-9', entitlement_ids: [] } })
  const res = await handleRevenueCatWebhook(req(body, 'the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls, { store }),
  })
  assertEquals(res.status, 200)
  assertEquals(store.get('user-9')?.is_premium, false)
  assertEquals(store.get('user-9')?.subscription_plan, 'free')
})
