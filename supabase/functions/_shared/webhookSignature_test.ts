import { assert, assertEquals, assertFalse, assertMatch } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  buildSignatureHeader,
  hmacSha256Hex,
  parseSignatureHeader,
  sha256Hex,
  verifySignatureHeader,
} from './webhookSignature.ts'

const SECRET = 'whsec_000000000000000000000000000000000000000000000001'
const OLD_SECRET = 'whsec_000000000000000000000000000000000000000000000002'
const BODY = '{"event_id":"evt_000000000000000000000001","event_type":"patient.enrolled"}'

Deno.test('hmacSha256Hex matches RFC 4231 test case 2', async () => {
  assertEquals(
    await hmacSha256Hex('Jefe', 'what do ya want for nothing?'),
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843'
  )
})

Deno.test('sha256Hex matches the FIPS 180-2 "abc" vector', async () => {
  assertEquals(await sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
})

Deno.test('header is t=<unix>,v1=<hmac of "t.body">', async () => {
  const header = await buildSignatureHeader([SECRET], 1793790000, BODY)
  assertMatch(header, /^t=1793790000,v1=[0-9a-f]{64}$/)
  assertEquals(header.split(',v1=')[1], await hmacSha256Hex(SECRET, `1793790000.${BODY}`))
})

Deno.test('a receiver with the secret verifies; tampered body, wrong secret and stale timestamp fail', async () => {
  const header = await buildSignatureHeader([SECRET], 1793790000, BODY)
  assert(await verifySignatureHeader(header, SECRET, BODY, 1793790010))
  assertFalse(await verifySignatureHeader(header, SECRET, BODY + ' ', 1793790010))
  assertFalse(await verifySignatureHeader(header, OLD_SECRET, BODY, 1793790010))
  assertFalse(await verifySignatureHeader(header, SECRET, BODY, 1793790000 + 301))
  assertFalse(await verifySignatureHeader('v1=abc', SECRET, BODY, 1793790000))
  assertFalse(await verifySignatureHeader(null, SECRET, BODY, 1793790000))
})

Deno.test('during rotation both the new and the previous secret verify', async () => {
  const header = await buildSignatureHeader([SECRET, OLD_SECRET], 1793790000, BODY)
  assertEquals(parseSignatureHeader(header)?.v1.length, 2)
  assert(await verifySignatureHeader(header, SECRET, BODY, 1793790000))
  assert(await verifySignatureHeader(header, OLD_SECRET, BODY, 1793790000))
})
