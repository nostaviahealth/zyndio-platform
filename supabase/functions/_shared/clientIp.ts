// Best-effort caller IP for per-IP rate limiting. Local dev / direct
// function invocation often has none of these headers; 'unknown' still
// buckets all such callers together rather than throwing, since the
// per-email-hash dimension (always available) is the one enumeration-safety
// actually depends on - per-IP is defense in depth on top of it.
export function clientIpFrom(req: Request): string {
  // The platform appends the observed peer as the last hop. The first hop is
  // whatever the caller sent, so it is not an identity.
  const forwarded = req.headers.get('x-forwarded-for')
  if (forwarded) {
    const hops = forwarded.split(',').map((part) => part.trim()).filter((part) => part.length > 0)
    const last = hops.length > 0 ? hops[hops.length - 1] : ''
    if (last.length > 0) return last
  }
  return 'unknown'
}

export async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}
