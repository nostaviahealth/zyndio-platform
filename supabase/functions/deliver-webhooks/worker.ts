// INT-02 delivery worker. Claims due deliveries (webhook_claim_due), signs
// and POSTs each one, and records every attempt (webhook_record_attempt) with
// the payload sha256, HTTP status and duration. Retry timing and dead-letter
// moves are decided in SQL (_webhook_retry_delay: 1m, 5m, 30m, 2h, 6h, 12h,
// 24h, then dead letter), so a crash between claim and record only delays a
// delivery until its 2-minute claim lapses - it is never lost (at-least-once;
// receivers dedupe on event_id).
import { buildSignatureHeader, sha256Hex } from '../_shared/webhookSignature.ts'

export interface RpcResult {
  data: unknown
  error: { code?: string; message: string } | null
}

export interface WorkerDeps {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<RpcResult>
  fetch(url: string, init: RequestInit): Promise<Response>
  /** Required for any non-local receiver. Absent means delivery fails closed. */
  connectPinned?: PinnedConnect
  resolveDns?: ResolveDns
  nowMs(): number
  timeoutMs: number
  allowLocalReceivers: boolean
  log(message: string, detail?: unknown): void
}

export interface Claim {
  delivery_id: string
  attempt_number: number
  url: string
  secrets: string[]
  envelope: {
    event_id: string
    event_type: string
    created_at: string
    schema_version: number
    data: unknown
  }
}

// Fixed field order so the bytes we sign and hash are stable across retries.
export function envelopeBody(envelope: Claim['envelope']): string {
  return JSON.stringify({
    event_id: envelope.event_id,
    event_type: envelope.event_type,
    created_at: envelope.created_at,
    schema_version: envelope.schema_version,
    data: envelope.data,
  })
}

export interface PinnedTarget {
  ip: string
  host: string
  port: number
}

export interface PinnedRequest {
  method: string
  pathAndQuery: string
  headers: Record<string, string>
  body: string
}

/** Connect to `ip` and speak HTTPS with SNI / certificate name `host`. */
export type PinnedConnect = (target: PinnedTarget, request: PinnedRequest) => Promise<{ status: number }>

export type ResolveDns = (host: string, record: 'A' | 'AAAA') => Promise<string[]>

// Second line of defence behind _webhook_url_error (registration time): only
// https to a public hostname, unless local receivers are explicitly allowed
// (local dev). No IP literals, no userinfo. This string check is not DNS.
export function isDeliverableUrl(raw: string, allowLocalReceivers: boolean): boolean {
  let url: URL
  try {
    url = new URL(raw)
  } catch {
    return false
  }
  if (url.username || url.password) return false
  const host = url.hostname.toLowerCase().replace(/\.$/, '')
  if (allowLocalReceivers && (host === 'localhost' || host === '127.0.0.1')) {
    return url.protocol === 'http:' || url.protocol === 'https:'
  }
  if (url.protocol !== 'https:') return false
  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host.endsWith('.local') ||
    host.endsWith('.internal') ||
    host.startsWith('[') ||
    /^[0-9.]+$/.test(host) ||
    /^0x/.test(host) ||
    !host.includes('.')
  ) {
    return false
  }
  return true
}

function ipv4Parts(ip: string): number[] | null {
  const parts = ip.split('.')
  if (parts.length !== 4) return null
  const nums = parts.map((p) => (/^\d{1,3}$/.test(p) ? Number(p) : NaN))
  if (nums.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) return null
  return nums
}

/** True for globally routable unicast. Private, loopback, link-local, mapped v4, documentation and multicast are false. */
export function isPublicIp(raw: string): boolean {
  const ip = raw.trim().toLowerCase().replace(/^\[|\]$/g, '')
  if (ip.includes('.')) {
    const v4 = ip.includes(':') ? ip.slice(ip.lastIndexOf(':') + 1) : ip
    const p = ipv4Parts(v4)
    if (!p) return false
    const [a, b] = p
    if (a === 0 || a === 10 || a === 127) return false
    if (a === 169 && b === 254) return false
    if (a === 172 && b >= 16 && b <= 31) return false
    if (a === 192 && b === 168) return false
    if (a === 100 && b >= 64 && b <= 127) return false
    if (a === 192 && b === 0 && p[2] === 0) return false
    if (a === 192 && b === 0 && p[2] === 2) return false
    if (a === 198 && b === 51 && p[2] === 100) return false
    if (a === 203 && b === 0 && p[2] === 113) return false
    if (a === 198 && (b === 18 || b === 19)) return false
    if (a >= 224) return false
    return true
  }
  return isPublicV6(ip)
}

function isPublicV6(ip: string): boolean {
  if (ip === '::' || ip === '::1') return false
  const mapped = ip.match(/^::ffff:([0-9.]+)$/)
  if (mapped) return isPublicIp(mapped[1])
  const groups = expandV6(ip)
  if (!groups) return false
  if (groups[0] === 0 && groups[1] === 0 && groups[2] === 0 && groups[3] === 0 && groups[4] === 0 && groups[5] === 0xffff) {
    return isPublicIp(v4FromGroups(groups[6], groups[7]))
  }
  const first = groups[0]
  if ((first & 0xff00) === 0xff00) return false
  if ((first & 0xfe00) === 0xfc00) return false
  if ((first & 0xffc0) === 0xfe80) return false
  if ((first & 0xffc0) === 0xfec0) return false
  if (first === 0x2002) return isPublicIp(v4FromGroups(groups[1], groups[2]))
  if (first === 0x2001 && groups[1] === 0x0db8) return false
  return (first & 0xe000) === 0x2000
}

function v4FromGroups(hi: number, lo: number): string {
  return `${(hi >> 8) & 0xff}.${hi & 0xff}.${(lo >> 8) & 0xff}.${lo & 0xff}`
}

function expandV6(ip: string): number[] | null {
  const halves = ip.split('::')
  if (halves.length > 2) return null
  const head = halves[0] ? halves[0].split(':') : []
  const tail = halves.length === 2 && halves[1] ? halves[1].split(':') : []
  if (head.some((g) => !/^[0-9a-f]{1,4}$/.test(g)) || tail.some((g) => !/^[0-9a-f]{1,4}$/.test(g))) return null
  const missing = 8 - head.length - tail.length
  if (missing < 0 || (halves.length === 1 && missing !== 0)) return null
  const full = [...head, ...Array(missing).fill('0'), ...tail]
  if (full.length !== 8) return null
  return full.map((g) => parseInt(g, 16))
}

/** Every A and AAAA answer, or null when any address is missing or not public. */
export async function publicAddresses(host: string, resolve: ResolveDns): Promise<string[] | null> {
  let v4: string[] = []
  let v6: string[] = []
  try {
    ;[v4, v6] = await Promise.all([
      resolve(host, 'A').catch(() => []),
      resolve(host, 'AAAA').catch(() => []),
    ])
  } catch {
    return null
  }
  const all = [...v4, ...v6]
  if (all.length === 0) return null
  if (all.some((ip) => !isPublicIp(ip))) return null
  return all
}

export async function deliverOne(deps: WorkerDeps, claim: Claim): Promise<string> {
  const body = envelopeBody(claim.envelope)
  const payloadSha256 = await sha256Hex(body)
  let status: number | null = null
  let error: string | null = null
  const started = deps.nowMs()

  if (!isDeliverableUrl(claim.url, deps.allowLocalReceivers)) {
    error = 'url_not_allowed'
  } else {
    const signature = await buildSignatureHeader(claim.secrets, Math.floor(deps.nowMs() / 1000), body)
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Zyndio-Webhooks/1.0',
      'X-Signature': signature,
      'X-Event-Id': claim.envelope.event_id,
      'X-Event-Type': claim.envelope.event_type,
      'X-Delivery-Attempt': String(claim.attempt_number),
    }
    const url = new URL(claim.url)
    const localLiteral = deps.allowLocalReceivers && (url.hostname === 'localhost' || url.hostname === '127.0.0.1')
    if (localLiteral) {
      const outcome = await postOnce(deps, claim.url, headers, body)
      status = outcome.status
      error = outcome.error
    } else if (!deps.resolveDns || !deps.connectPinned) {
      // Hostname checks do not stop a public name that resolves to a link-local
      // or loopback address. Without a pinned connect, do not call fetch.
      error = 'dns_pin_unavailable'
    } else {
      const ips = await publicAddresses(url.hostname, deps.resolveDns)
      if (!ips) {
        error = 'url_not_allowed'
      } else {
        try {
          const res = await deps.connectPinned(
            { ip: ips[0], host: url.hostname, port: url.port ? Number(url.port) : 443 },
            { method: 'POST', pathAndQuery: `${url.pathname}${url.search}`, headers, body },
          )
          status = res.status
          if (status >= 300 && status < 400) error = 'redirect_blocked'
          else if (status < 200 || status > 299) error = `http_${status}`
        } catch (err) {
          const name = (err as { name?: string } | null)?.name
          error = name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network_error'
        }
      }
    }
  }

  const durationMs = Math.max(0, Math.round(deps.nowMs() - started))
  const { data, error: recordError } = await deps.rpc('webhook_record_attempt', {
    p_delivery_id: claim.delivery_id,
    p_payload_sha256: payloadSha256,
    p_response_status: status,
    p_duration_ms: durationMs,
    p_error: error,
  })
  if (recordError) {
    // Left claimed; the claim lapses after 2 minutes and the delivery is retried.
    deps.log('deliver-webhooks: webhook_record_attempt failed', recordError)
    return 'record_failed'
  }
  return data as string
}

async function postOnce(
  deps: WorkerDeps,
  url: string,
  headers: Record<string, string>,
  body: string,
): Promise<{ status: number | null; error: string | null }> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(new DOMException('timed out', 'TimeoutError')), deps.timeoutMs)
  try {
    const res = await deps.fetch(url, { method: 'POST', headers, body, redirect: 'manual', signal: controller.signal })
    await res.body?.cancel().catch(() => {})
    if (res.status >= 300 && res.status < 400) return { status: res.status, error: 'redirect_blocked' }
    if (res.status < 200 || res.status > 299) return { status: res.status, error: `http_${res.status}` }
    return { status: res.status, error: null }
  } catch (err) {
    const name = (err as { name?: string } | null)?.name
    return { status: null, error: name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network_error' }
  } finally {
    clearTimeout(timer)
  }
}

type DenoNet = {
  resolveDns?(host: string, record: 'A' | 'AAAA'): Promise<string[]>
  connect?(opts: { hostname: string; port: number }): Promise<DenoConn>
  startTls?(conn: DenoConn, opts: { hostname: string }): Promise<DenoConn>
}

type DenoConn = {
  readable: ReadableStream<Uint8Array>
  writable: WritableStream<Uint8Array>
  close(): void
}

/** Present only when this runtime can resolve DNS. Tests inject their own. */
export function denoResolveDns(): ResolveDns | undefined {
  const deno = (globalThis as { Deno?: DenoNet }).Deno
  if (!deno?.resolveDns) return undefined
  const resolve = deno.resolveDns.bind(deno)
  return (host, record) => resolve(host, record)
}

/**
 * TCP to the pinned address, TLS with the original hostname as SNI.
 * Returns undefined when the runtime cannot do that, so delivery fails closed
 * instead of calling fetch() (which would resolve the name again).
 */
export function denoPinnedConnect(): PinnedConnect | undefined {
  const deno = (globalThis as { Deno?: DenoNet }).Deno
  if (!deno?.connect || !deno?.startTls) return undefined
  const connect = deno.connect.bind(deno)
  const startTls = deno.startTls.bind(deno)
  return async (target, request) => {
    const tcp = await connect({ hostname: target.ip, port: target.port })
    const tls = await startTls(tcp, { hostname: target.host })
    const payload = new TextEncoder().encode(request.body)
    const head = [
      `${request.method} ${request.pathAndQuery || '/'} HTTP/1.1`,
      `Host: ${target.host}`,
      ...Object.entries(request.headers).map(([k, v]) => `${k}: ${v}`),
      `Content-Length: ${payload.byteLength}`,
      'Connection: close',
      '',
      '',
    ].join('\r\n')
    const writer = tls.writable.getWriter()
    await writer.write(new TextEncoder().encode(head))
    await writer.write(payload)
    await writer.close()
    const reader = tls.readable.getReader()
    const decoder = new TextDecoder()
    let buf = ''
    while (!buf.includes('\r\n') && buf.length < 4096) {
      const { value, done } = await reader.read()
      if (done) break
      buf += decoder.decode(value, { stream: true })
    }
    await reader.cancel().catch(() => {})
    try { tls.close() } catch { /* already closed */ }
    const status = buf.match(/^HTTP\/1\.[01] (\d{3})/)
    if (!status) throw new Error('no http status')
    return { status: Number(status[1]) }
  }
}

export async function deliverDue(
  deps: WorkerDeps,
  opts: { batchSize?: number; budgetMs?: number } = {}
): Promise<{ attempted: number; outcomes: Record<string, number> }> {
  const batchSize = opts.batchSize ?? 25
  const deadline = deps.nowMs() + (opts.budgetMs ?? 40_000)
  const outcomes: Record<string, number> = {}
  let attempted = 0

  while (deps.nowMs() < deadline) {
    const { data, error } = await deps.rpc('webhook_claim_due', { p_limit: batchSize })
    if (error) {
      deps.log('deliver-webhooks: webhook_claim_due failed', error)
      break
    }
    const claims = (data ?? []) as Claim[]
    if (claims.length === 0) break
    const results = await Promise.all(claims.map((c) => deliverOne(deps, c)))
    for (const r of results) outcomes[r] = (outcomes[r] ?? 0) + 1
    attempted += claims.length
    if (claims.length < batchSize) break
  }
  return { attempted, outcomes }
}
