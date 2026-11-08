import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { clientIpFrom, sha256Hex } from './clientIp.ts'

Deno.test('clientIpFrom uses the hop the gateway appended, not the caller-supplied first hop', () => {
  // Caller sent "x-forwarded-for: 203.0.113.9"; the gateway appended the real peer.
  const req = new Request('http://localhost', {
    headers: { 'x-forwarded-for': '203.0.113.9, 198.51.100.77' },
  })
  assertEquals(clientIpFrom(req, 0), '198.51.100.77')
})

Deno.test('clientIpFrom: rotating a spoofed first hop does not change the bucket', () => {
  const a = new Request('http://localhost', { headers: { 'x-forwarded-for': '1.1.1.1, 198.51.100.77' } })
  const b = new Request('http://localhost', { headers: { 'x-forwarded-for': '2.2.2.2, 198.51.100.77' } })
  assertEquals(clientIpFrom(a, 0), clientIpFrom(b, 0))
})

Deno.test('clientIpFrom skips trusted proxy hops from the right', () => {
  // visitor (set by the Cloudflare worker), then the worker address appended by the gateway
  const req = new Request('http://localhost', {
    headers: { 'x-forwarded-for': '203.0.113.9, 192.0.2.10' },
  })
  assertEquals(clientIpFrom(req, 1), '203.0.113.9')
})

Deno.test('clientIpFrom returns unknown when there are fewer hops than trusted proxies', () => {
  const req = new Request('http://localhost', { headers: { 'x-forwarded-for': '203.0.113.9' } })
  assertEquals(clientIpFrom(req, 1), 'unknown')
})

Deno.test('clientIpFrom ignores caller-controlled x-real-ip', () => {
  const req = new Request('http://localhost', { headers: { 'x-real-ip': '198.51.100.4' } })
  assertEquals(clientIpFrom(req, 0), 'unknown')
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
