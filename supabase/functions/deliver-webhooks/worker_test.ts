// INT-02 delivery worker: signing, attempt logging, failure classification.
// Retry timing / dead letter live in SQL (supabase/tests/760_int01_partner_api.sql).
import { assert, assertEquals, assertFalse } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { Claim, deliverDue, deliverOne, envelopeBody, isDeliverableUrl, isPublicIp, PinnedTarget, RpcResult, WorkerDeps } from './worker.ts'
import { sha256Hex, verifySignatureHeader } from '../_shared/webhookSignature.ts'

const SECRET = 'whsec_000000000000000000000000000000000000000000000001'
const PREVIOUS = 'whsec_000000000000000000000000000000000000000000000002'

function claim(n: number, overrides: Partial<Claim> = {}): Claim {
  return {
    delivery_id: `delivery-${n}`,
    attempt_number: 1,
    url: 'https://hooks.example.test/in',
    secrets: [SECRET],
    envelope: {
      event_id: `evt_${String(n).padStart(24, '0')}`,
      event_type: 'patient.enrolled',
      created_at: '2026-11-04T10:00:00.000Z',
      schema_version: 1,
      data: { zyndio_patient_id: 'zp-fictional-001', status: 'invited' },
    },
    ...overrides,
  }
}

function harness(respond: (req: Request) => Promise<Response> | Response, queue: Claim[][] = []) {
  const recorded: Record<string, unknown>[] = []
  const sent: Request[] = []
  const pinned: PinnedTarget[] = []
  let clock = 1793790000000
  const deps: WorkerDeps = {
    rpc(fn: string, args: Record<string, unknown>): Promise<RpcResult> {
      if (fn === 'webhook_claim_due') return Promise.resolve({ data: queue.shift() ?? [], error: null })
      if (fn === 'webhook_record_attempt') {
        recorded.push(args)
        const ok = typeof args.p_response_status === 'number' && args.p_response_status >= 200 && args.p_response_status < 300
        return Promise.resolve({ data: ok ? 'succeeded' : 'retry_scheduled', error: null })
      }
      throw new Error(`unexpected rpc ${fn}`)
    },
    async fetch(url, init) {
      const req = new Request(url, init)
      sent.push(req.clone())
      clock += 37
      return await respond(req)
    },
    resolveDns: async (_host, record) => (record === 'A' ? ['8.8.8.8'] : []),
    connectPinned: async (target, request) => {
      pinned.push(target)
      const req = new Request(`https://${target.host}${request.pathAndQuery}`, {
        method: request.method,
        headers: request.headers,
        body: request.body,
        redirect: 'manual',
      })
      sent.push(req.clone())
      clock += 37
      const res = await respond(req)
      return { status: res.status }
    },
    nowMs: () => clock,
    timeoutMs: 1000,
    allowLocalReceivers: false,
    log: () => {},
  }
  return { deps, recorded, sent, pinned }
}

Deno.test('envelope body has exactly the five documented fields in a fixed order', () => {
  assertEquals(
    Object.keys(JSON.parse(envelopeBody(claim(1).envelope))),
    ['event_id', 'event_type', 'created_at', 'schema_version', 'data']
  )
})

Deno.test('a delivery is signed with X-Signature over "t.body" and logged with sha256, status, timing', async () => {
  const { deps, recorded, sent } = harness(() => new Response('ok', { status: 200 }))
  assertEquals(await deliverOne(deps, claim(1)), 'succeeded')

  const req = sent[0]
  const body = await req.text()
  assertEquals(req.method, 'POST')
  assertEquals(req.headers.get('content-type'), 'application/json')
  assertEquals(req.headers.get('x-event-id'), 'evt_000000000000000000000001')
  assert(await verifySignatureHeader(req.headers.get('x-signature'), SECRET, body, 1793790000))

  assertEquals(recorded[0].p_payload_sha256, await sha256Hex(body))
  assertEquals(recorded[0].p_response_status, 200)
  assertEquals(recorded[0].p_duration_ms, 37)
  assertEquals(recorded[0].p_error, null)
})

Deno.test('during a rotation both secrets sign the delivery', async () => {
  const { deps, sent } = harness(() => new Response(null, { status: 204 }))
  await deliverOne(deps, claim(1, { secrets: [SECRET, PREVIOUS] }))
  const body = await sent[0].text()
  assert(await verifySignatureHeader(sent[0].headers.get('x-signature'), SECRET, body, 1793790000))
  assert(await verifySignatureHeader(sent[0].headers.get('x-signature'), PREVIOUS, body, 1793790000))
})

Deno.test('non-2xx, redirects, network errors and timeouts are recorded as failures', async () => {
  const cases: [() => Promise<Response> | Response, number | null, string][] = [
    [() => new Response('nope', { status: 500 }), 500, 'http_500'],
    [() => new Response(null, { status: 302, headers: { location: 'https://elsewhere.example.test' } }), 302, 'redirect_blocked'],
    [() => Promise.reject(new TypeError('connection refused')), null, 'network_error'],
    [() => Promise.reject(new DOMException('timed out', 'TimeoutError')), null, 'timeout'],
  ]
  for (const [respond, status, error] of cases) {
    const { deps, recorded } = harness(respond)
    assertEquals(await deliverOne(deps, claim(1)), 'retry_scheduled')
    assertEquals(recorded[0].p_response_status, status)
    assertEquals(recorded[0].p_error, error)
  }
})

Deno.test('redirects are not followed', async () => {
  const { deps, sent } = harness(() => new Response(null, { status: 307, headers: { location: 'https://169.254.169.254/' } }))
  await deliverOne(deps, claim(1))
  assertEquals(sent.length, 1)
  assertEquals(sent[0].redirect, 'manual')
})

Deno.test('URLs that point inside the network are never fetched, only logged as failed', async () => {
  for (const url of ['https://10.0.0.1/in', 'https://localhost/in', 'http://hooks.example.test/in', 'https://metadata.internal/', 'https://[::1]/in']) {
    const { deps, recorded, sent } = harness(() => new Response(null, { status: 200 }))
    await deliverOne(deps, claim(1, { url }))
    assertEquals(sent.length, 0, url)
    assertEquals(recorded[0].p_error, 'url_not_allowed')
  }
})

Deno.test('isDeliverableUrl: local receivers only with the explicit dev switch', () => {
  assert(isDeliverableUrl('https://hooks.example.test/in', false))
  assertFalse(isDeliverableUrl('http://127.0.0.1:9999/in', false))
  assert(isDeliverableUrl('http://127.0.0.1:9999/in', true))
  assertFalse(isDeliverableUrl('https://user:pw@hooks.example.test/in', false))
  assertFalse(isDeliverableUrl('not a url', false))
})

Deno.test('a public-looking name that resolves to a non-public address is not connected', async () => {
  const cases: [string, string[]][] = [
    ['169.254.169.254.nip.io', ['169.254.169.254']],
    ['127.0.0.1.nip.io', ['127.0.0.1']],
    ['metadata.example.test', ['::ffff:169.254.169.254']],
    ['split.example.test', ['8.8.8.8', '10.1.2.3']],
    ['empty.example.test', []],
  ]
  for (const [host, answers] of cases) {
    const { deps, recorded, pinned, sent } = harness(() => new Response('no', { status: 200 }))
    deps.resolveDns = async () => answers
    await deliverOne(deps, claim(1, { url: `https://${host}/latest` }))
    assertEquals(pinned.length, 0, host)
    assertEquals(sent.length, 0, host)
    assertEquals(recorded[0].p_error, 'url_not_allowed')
  }
})

Deno.test('delivery connects to the resolved public address and keeps the hostname for SNI', async () => {
  const { deps, pinned, sent } = harness(() => new Response('ok', { status: 200 }))
  let lookups = 0
  deps.resolveDns = async (host, record) => {
    lookups += 1
    assertEquals(host, 'hooks.example.test')
    return record === 'A' ? ['8.8.8.8'] : ['2001:4860:4860::8888']
  }
  assertEquals(await deliverOne(deps, claim(1)), 'succeeded')
  assertEquals(lookups, 2)
  assertEquals(pinned, [{ ip: '8.8.8.8', host: 'hooks.example.test', port: 443 }])
  assertEquals(sent.length, 1)
  assert(sent[0].url.startsWith('https://hooks.example.test/'))
})

Deno.test('without a pinned connect, delivery fails closed and does not fetch the hostname', async () => {
  const { deps, recorded, sent } = harness(() => new Response('ok', { status: 200 }))
  deps.connectPinned = undefined
  await deliverOne(deps, claim(1))
  assertEquals(sent.length, 0)
  assertEquals(recorded[0].p_error, 'dns_pin_unavailable')
})

Deno.test('isPublicIp denies loopback, link-local, private and mapped addresses', () => {
  for (const ip of ['127.0.0.1', '10.1.2.3', '169.254.169.254', '192.168.1.1', '172.16.0.1', '::1', '::ffff:127.0.0.1', 'fe80::1', 'fd00::1']) {
    assertFalse(isPublicIp(ip), ip)
  }
  assert(isPublicIp('8.8.8.8'))
  assert(isPublicIp('2001:4860:4860::8888'))
})

Deno.test('deliverDue drains batches until the queue is empty', async () => {
  const { deps, recorded } = harness(() => new Response(null, { status: 200 }), [[claim(1), claim(2)], [claim(3)], []])
  const result = await deliverDue(deps, { batchSize: 2 })
  assertEquals(result.attempted, 3)
  assertEquals(result.outcomes, { succeeded: 3 })
  assertEquals(recorded.length, 3)
})
