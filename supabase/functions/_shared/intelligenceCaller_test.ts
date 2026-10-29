import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { classifyIntelligenceCaller } from './intelligenceCaller.ts'

// Unsigned test tokens: header.payload.signature with a fake signature -
// classification only reads the role claim; GoTrue verifies the real token
// afterwards in the function.
function fakeJwt(payload: Record<string, unknown>): string {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64(payload)}.fake-signature`
}

Deno.test('intelligence caller: missing Authorization is 401', () => {
  assertEquals(classifyIntelligenceCaller(null), { ok: false, status: 401, error: 'Missing authorization header' })
})

Deno.test('intelligence caller: anon-role token is 403 (wrong role)', () => {
  assertEquals(classifyIntelligenceCaller(`Bearer ${fakeJwt({ role: 'anon' })}`), {
    ok: false,
    status: 403,
    error: 'forbidden',
  })
})

Deno.test('intelligence caller: service_role token is 403 (not a signed-in user)', () => {
  assertEquals(classifyIntelligenceCaller(`Bearer ${fakeJwt({ role: 'service_role' })}`), {
    ok: false,
    status: 403,
    error: 'forbidden',
  })
})

Deno.test('intelligence caller: non-JWT key (e.g. sb_publishable_...) is 403', () => {
  assertEquals(classifyIntelligenceCaller('Bearer sb_publishable_fictional'), {
    ok: false,
    status: 403,
    error: 'forbidden',
  })
})

Deno.test('intelligence caller: authenticated-role token passes to session verification', () => {
  const token = fakeJwt({ role: 'authenticated', sub: '00000000-0000-4000-8000-000000000001' })
  assertEquals(classifyIntelligenceCaller(`Bearer ${token}`), { ok: true, token })
})
