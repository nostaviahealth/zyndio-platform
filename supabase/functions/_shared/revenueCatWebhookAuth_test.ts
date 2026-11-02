import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { isAuthorizedRevenueCatRequest } from './revenueCatWebhookAuth.ts'

Deno.test('rejects a missing Authorization header', () => {
  assertEquals(isAuthorizedRevenueCatRequest(null, 'correct-secret'), false)
  assertEquals(isAuthorizedRevenueCatRequest(undefined, 'correct-secret'), false)
})

Deno.test('rejects a wrong secret', () => {
  assertEquals(isAuthorizedRevenueCatRequest('wrong-secret', 'correct-secret'), false)
})

Deno.test('rejects when the expected secret (env var) is unset or empty - fail closed', () => {
  assertEquals(isAuthorizedRevenueCatRequest('correct-secret', undefined), false)
  assertEquals(isAuthorizedRevenueCatRequest('correct-secret', ''), false)
  // Even an empty header must not match an empty/unset expected secret.
  assertEquals(isAuthorizedRevenueCatRequest('', ''), false)
})

Deno.test('accepts the exact configured secret', () => {
  assert(isAuthorizedRevenueCatRequest('correct-secret', 'correct-secret'))
})

Deno.test('is case-sensitive and exact-match (no trimming/partial match)', () => {
  assertEquals(isAuthorizedRevenueCatRequest('Correct-Secret', 'correct-secret'), false)
  assertEquals(isAuthorizedRevenueCatRequest('correct-secret ', 'correct-secret'), false)
  assertEquals(isAuthorizedRevenueCatRequest('correct-secre', 'correct-secret'), false)
})
