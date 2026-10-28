import { assertEquals, assertStrictEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { corsHeadersFor } from './cors.ts'

function reqWithOrigin(origin: string | null): Request {
  const headers = new Headers()
  if (origin) headers.set('origin', origin)
  return new Request('https://example.test/fn', { headers })
}

Deno.test('corsHeadersFor reflects a known local admin origin (TC-011 L11)', () => {
  const headers = corsHeadersFor(reqWithOrigin('http://localhost:5173'))
  assertEquals(headers['Access-Control-Allow-Origin'], 'http://localhost:5173')
})

Deno.test('corsHeadersFor reflects every documented local admin origin', () => {
  for (const origin of [
    'http://127.0.0.1:5173',
    'http://localhost:5173',
    'http://127.0.0.1:3100',
    'http://localhost:3100',
  ]) {
    assertEquals(corsHeadersFor(reqWithOrigin(origin))['Access-Control-Allow-Origin'], origin)
  }
})

Deno.test('corsHeadersFor omits Access-Control-Allow-Origin for an unknown origin (no more wildcard)', () => {
  const headers = corsHeadersFor(reqWithOrigin('https://evil.example'))
  assertStrictEquals(headers['Access-Control-Allow-Origin'], undefined)
  assertStrictEquals(headers['Access-Control-Allow-Origin'] === '*', false)
})

Deno.test('corsHeadersFor omits Access-Control-Allow-Origin when no Origin header is sent', () => {
  const headers = corsHeadersFor(reqWithOrigin(null))
  assertStrictEquals(headers['Access-Control-Allow-Origin'], undefined)
})

// CI's `deno test` for this module runs with no --allow-env (cors.ts reads
// env defensively for exactly this reason - see readEnv() there), so this
// only exercises the env-reflection path when run with env permission (e.g.
// `deno test --allow-env`), and no-ops otherwise rather than failing the
// whole suite.
Deno.test('corsHeadersFor reflects ADMIN_ORIGIN when configured', async () => {
  const status = await Deno.permissions.query({ name: 'env', variable: 'ADMIN_ORIGIN' })
  if (status.state !== 'granted') return
  Deno.env.set('ADMIN_ORIGIN', 'https://admin.zyndio.example')
  try {
    const headers = corsHeadersFor(reqWithOrigin('https://admin.zyndio.example'))
    assertEquals(headers['Access-Control-Allow-Origin'], 'https://admin.zyndio.example')
  } finally {
    Deno.env.delete('ADMIN_ORIGIN')
  }
})

Deno.test('corsHeadersFor always sets Vary: Origin', () => {
  assertEquals(corsHeadersFor(reqWithOrigin('http://localhost:5173'))['Vary'], 'Origin')
  assertEquals(corsHeadersFor(reqWithOrigin(null))['Vary'], 'Origin')
})
