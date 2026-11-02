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

function clientFactory(calls: string[], updateResult: { error: unknown } = { error: null }) {
  return () => ({
    from(table: string) {
      calls.push(table)
      return {
        update(_patch: Record<string, unknown>) {
          return { eq: async (_col: string, _val: string) => updateResult }
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

Deno.test('correct secret -> accepted, writes patient_accounts (not profiles)', async () => {
  const calls: string[] = []
  const res = await handleRevenueCatWebhook(req(VALID_BODY, 'the-secret'), {
    env: fakeEnv({ REVENUECAT_WEBHOOK_AUTH: 'the-secret' }),
    createServiceClient: clientFactory(calls),
  })
  assertEquals(res.status, 200)
  assertEquals(calls, ['patient_accounts'])
})
