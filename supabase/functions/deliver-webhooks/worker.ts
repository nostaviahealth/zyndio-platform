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

// Second line of defence behind _webhook_url_error (registration time): only
// https to a public hostname, unless local receivers are explicitly allowed
// (local dev). No IP literals, no userinfo.
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

export async function deliverOne(deps: WorkerDeps, claim: Claim): Promise<string> {
  const body = envelopeBody(claim.envelope)
  const payloadSha256 = await sha256Hex(body)
  let status: number | null = null
  let error: string | null = null
  const started = deps.nowMs()

  if (!isDeliverableUrl(claim.url, deps.allowLocalReceivers)) {
    error = 'url_not_allowed'
  } else {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(new DOMException('timed out', 'TimeoutError')), deps.timeoutMs)
    try {
      const signature = await buildSignatureHeader(claim.secrets, Math.floor(deps.nowMs() / 1000), body)
      const res = await deps.fetch(claim.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Zyndio-Webhooks/1.0',
          'X-Signature': signature,
          'X-Event-Id': claim.envelope.event_id,
          'X-Event-Type': claim.envelope.event_type,
          'X-Delivery-Attempt': String(claim.attempt_number),
        },
        body,
        redirect: 'manual',
        signal: controller.signal,
      })
      status = res.status
      // The response body is never stored or logged.
      await res.body?.cancel().catch(() => {})
      if (status < 200 || status > 299) error = `http_${status}`
    } catch (err) {
      const name = (err as { name?: string } | null)?.name
      error = name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network_error'
    } finally {
      clearTimeout(timer)
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
