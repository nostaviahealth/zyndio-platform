// INT-02 webhook signatures. Header format:
//
//   X-Signature: t=<unix seconds>,v1=<hex HMAC-SHA256(secret, "<t>.<raw body>")>
//
// The HMAC key is the endpoint secret string exactly as issued (whsec_...),
// UTF-8 encoded. During a secret rotation the header carries one v1= per
// live secret (new first, then the previous one for 24h), so a receiver that
// still has the old secret keeps verifying. Receivers should reject a
// timestamp outside their tolerance (default 5 minutes) to stop replays.
// verifySignatureHeader() is the reference receiver check (docs + tests).

const encoder = new TextEncoder()

function toHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('')
}

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  return toHex(await crypto.subtle.sign('HMAC', key, encoder.encode(message)))
}

export async function sha256Hex(value: string): Promise<string> {
  return toHex(await crypto.subtle.digest('SHA-256', encoder.encode(value)))
}

export async function buildSignatureHeader(secrets: string[], timestamp: number, body: string): Promise<string> {
  if (secrets.length === 0) throw new Error('at least one signing secret is required')
  const t = Math.floor(timestamp)
  const signatures = await Promise.all(secrets.map((s) => hmacSha256Hex(s, `${t}.${body}`)))
  return [`t=${t}`, ...signatures.map((v) => `v1=${v}`)].join(',')
}

export function parseSignatureHeader(header: string | null | undefined): { t: number; v1: string[] } | null {
  if (!header) return null
  let t: number | null = null
  const v1: string[] = []
  for (const part of header.split(',')) {
    const eq = part.indexOf('=')
    if (eq < 0) continue
    const k = part.slice(0, eq).trim()
    const v = part.slice(eq + 1).trim()
    if (k === 't' && /^\d{1,12}$/.test(v)) t = Number(v)
    else if (k === 'v1' && /^[0-9a-f]{64}$/.test(v)) v1.push(v)
  }
  if (t === null || v1.length === 0) return null
  return { t, v1 }
}

function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

export async function verifySignatureHeader(
  header: string | null | undefined,
  secret: string,
  body: string,
  nowSeconds: number,
  toleranceSeconds = 300
): Promise<boolean> {
  const parsed = parseSignatureHeader(header)
  if (!parsed) return false
  if (Math.abs(nowSeconds - parsed.t) > toleranceSeconds) return false
  const expected = await hmacSha256Hex(secret, `${parsed.t}.${body}`)
  return parsed.v1.some((candidate) => timingSafeEqualHex(candidate, expected))
}
