// Best-effort caller IP for per-IP rate limiting. Local dev / direct
// function invocation often has none of these headers; 'unknown' still
// buckets all such callers together rather than throwing, since the
// per-email-hash dimension (always available) is the one enumeration-safety
// actually depends on - per-IP is defense in depth on top of it.
//
// Only hops added by infrastructure we trust identify the caller. Each proxy
// APPENDS the peer it saw to x-forwarded-for, so the left-most entries are
// whatever the caller chose to send and must never be used: reading the first
// hop let any client pick a fresh IP per request and walk straight past the
// per-IP limits. The Supabase gateway appends the real peer as the last hop.
//
// TRUSTED_PROXY_HOPS is the number of extra trusted proxies in front of the
// gateway (default 0). The Cloudflare worker in supabase/proxy-worker.js is
// one such hop: it rewrites x-forwarded-for to the visitor's address, and the
// gateway then appends the worker's own address, so deployments behind it
// set TRUSTED_PROXY_HOPS=1. x-real-ip is not read: the gateway does not
// overwrite it, so it is caller-controlled.

function trustedProxyHops(): number {
  let raw: string | undefined
  try {
    raw = Deno.env.get('TRUSTED_PROXY_HOPS')
  } catch {
    raw = undefined
  }
  const n = Number.parseInt(raw ?? '0', 10)
  return Number.isFinite(n) && n >= 0 && n <= 5 ? n : 0
}

export function clientIpFrom(req: Request, extraTrustedHops = trustedProxyHops()): string {
  const forwarded = req.headers.get('x-forwarded-for')
  if (!forwarded) return 'unknown'
  const hops = forwarded
    .split(',')
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
  const index = hops.length - 1 - extraTrustedHops
  // Fewer hops than trusted proxies means the request did not come through
  // the expected chain; do not guess from caller-supplied entries.
  if (index < 0) return 'unknown'
  return hops[index]
}

export async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}
