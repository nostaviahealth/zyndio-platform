import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { clientIpFrom, sha256Hex } from './clientIp.ts'

Deno.test('clientIpFrom prefers the first x-forwarded-for hop', () => {
  const req = new Request('http://localhost', {
    headers: { 'x-forwarded-for': '203.0.113.9, 10.0.0.1' },
  })
  assertEquals(clientIpFrom(req), '203.0.113.9')
})

Deno.test('clientIpFrom falls back to x-real-ip', () => {
  const req = new Request('http://localhost', { headers: { 'x-real-ip': '198.51.100.4' } })
  assertEquals(clientIpFrom(req), '198.51.100.4')
})

Deno.test('clientIpFrom falls back to unknown rather than throwing', () => {
  const req = new Request('http://localhost')
  assertEquals(clientIpFrom(req), 'unknown')
})

Deno.test('sha256Hex is deterministic and does not echo the input', async () => {
  const a = await sha256Hex('alice@example.test')
  const b = await sha256Hex('alice@example.test')
  const c = await sha256Hex('bob@example.test')
  assertEquals(a, b)
  assertNotEquals(a, 'alice@example.test')
  assertNotEquals(a, c)
  assertEquals(a.length, 64)
})
