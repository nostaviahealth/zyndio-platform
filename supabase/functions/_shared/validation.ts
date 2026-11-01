// Pure, dependency-free helpers shared by every TC-005 edge function. No Deno
// or Node-specific imports here (only the global Web Crypto API, which both
// runtimes provide) so this module can be unit tested directly by vitest
// without a Deno runtime (L12 - the actual tests live alongside this file
// and run via `deno test`: see supabase/functions/_shared/validation_test.ts).

export const APP_ROLES = ['org_admin', 'physician', 'care_coordinator', 'read_only'] as const
export type AppRole = (typeof APP_ROLES)[number]

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function normalizeEmail(email: unknown): string | null {
  if (typeof email !== 'string') return null
  const trimmed = email.trim().toLowerCase()
  return trimmed.length > 0 ? trimmed : null
}

export function isValidEmail(email: unknown): email is string {
  return typeof email === 'string' && EMAIL_RE.test(email)
}

export function isValidAppRole(role: unknown): role is AppRole {
  return typeof role === 'string' && (APP_ROLES as readonly string[]).includes(role)
}

// Rank: org_admin (3) > physician (2) > care_coordinator (1) > read_only (0).
// Actor may grant a role iff target rank <= actor rank. Mirrors
// public.can_grant_role() so invite-user can refuse before any write.
const ROLE_RANK: Record<AppRole, number> = {
  org_admin: 3,
  physician: 2,
  care_coordinator: 1,
  read_only: 0,
}

export function canGrantRole(actorRole: AppRole, targetRole: AppRole): boolean {
  return ROLE_RANK[actorRole] >= ROLE_RANK[targetRole]
}

// Invite Full name: trim, non-empty, capped so a pasted novel can't bloat
// invites / user_metadata. Returns null when the value is unusable.
export const MAX_FULL_NAME_LENGTH = 200

export function normalizeFullName(name: unknown): string | null {
  if (typeof name !== 'string') return null
  const trimmed = name.trim().replace(/\s+/g, ' ')
  if (trimmed.length === 0 || trimmed.length > MAX_FULL_NAME_LENGTH) return null
  return trimmed
}

// TC-018 (Henry's calls, 1 Nov 2026; Clara PR #23 review finding #2):
// create-patient's own text field caps. mrn is generous for real-world
// medical record number formats while still blocking abuse (a 20MB mrn made
// it into the database before this). email matches the 254-char RFC 5321
// mailbox cap already used client-side by the invite dialog (TC-018.md
// item 1, L33).
export const MAX_MRN_LENGTH = 64
export const MAX_EMAIL_LENGTH = 254

// Clara PR #23 review finding #2: reject an oversized request body with 413
// before it is ever parsed. Content-Length is read straight off the
// request, with no body read at all - the cheapest possible rejection for
// an honest client that declared its real size.
export function declaredBodyTooLarge(req: Request, maxBytes: number): boolean {
  const declared = req.headers.get('content-length')
  if (declared === null) return false
  const n = Number(declared)
  return Number.isFinite(n) && n > maxBytes
}

// Backstop for a missing or understated Content-Length: once the body text
// is actually in hand, its real UTF-8 byte length (not JS string length,
// which undercounts multi-byte characters) is checked before JSON.parse
// ever sees it.
export function actualBodyTooLarge(text: string, maxBytes: number): boolean {
  return new TextEncoder().encode(text).length > maxBytes
}

// Clara PR #23 review finding #6: `req.json().catch(() => ({}))` only
// catches a JSON *parse* error - valid-but-wrong-shape JSON (the literal
// `null`, an array, a string/number/boolean) sails through as that exact
// value, and the first `body.<field>` read on a non-object then throws an
// uncaught TypeError. An empty body stays accepted as `{}` (unchanged prior
// behaviour - no body at all is not the same bug as a wrongly-shaped one).
export function parseJsonObject(raw: string): { ok: true; body: Record<string, unknown> } | { ok: false } {
  if (raw.length === 0) return { ok: true, body: {} }
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return { ok: false }
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return { ok: false }
  }
  return { ok: true, body: parsed as Record<string, unknown> }
}

export function isValidUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_RE.test(value)
}

// Minimum length only - NIST 800-63B style, no composition rules. The
// blocklist check (public.password_is_blocked) happens server-side in
// Postgres, not here.
export const MIN_PASSWORD_LENGTH = 12

export function isPasswordLongEnough(password: unknown): password is string {
  return typeof password === 'string' && password.length >= MIN_PASSWORD_LENGTH
}

export function parseBearerToken(authorizationHeader: string | null | undefined): string | null {
  if (!authorizationHeader) return null
  const match = authorizationHeader.match(/^Bearer\s+(.+)$/i)
  return match ? match[1].trim() : null
}

// Decodes (without verifying) the payload of a JWT already validated by
// GoTrue (via supabase.auth.getUser). Mirrors
// scripts/tc005-auth-hooks-live-check.ts's decodeJwtPayload.
export function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('not a JWT')
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
  const json = atob(padded)
  return JSON.parse(json)
}

export function hasAal2Claim(payload: Record<string, unknown>): boolean {
  return payload.aal === 'aal2'
}

// Random, URL-safe invite/reset token. 32 bytes -> 256 bits of entropy.
export function generateToken(): string {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

export async function hashTokenHex(token: string): Promise<string> {
  const data = new TextEncoder().encode(token)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}

// M8: a throwaway password for the auth.users row invite-user creates ahead
// of the invite being accepted. Nobody is ever meant to know or use it - the
// invitee sets their real password in accept-invite - but GoTrue's
// password_requirements (lower_upper_letters_digits_symbols, config.toml)
// now rejects generateToken()'s plain-hex output, which has no uppercase
// and no symbol. This generates a random password that always satisfies all
// four character classes, independent of that policy string.
const LOWER = 'abcdefghijklmnopqrstuvwxyz'
const UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const DIGITS = '0123456789'
const SYMBOLS = '!@#$%^&*()_+-='
const ALL = LOWER + UPPER + DIGITS + SYMBOLS

function randomFrom(charset: string): string {
  const bytes = new Uint8Array(1)
  crypto.getRandomValues(bytes)
  return charset[bytes[0] % charset.length]
}

export function generatePlaceholderPassword(): string {
  const required = [randomFrom(LOWER), randomFrom(UPPER), randomFrom(DIGITS), randomFrom(SYMBOLS)]
  const rest = Array.from({ length: 28 }, () => randomFrom(ALL))
  const chars = [...required, ...rest]
  // Fisher-Yates shuffle so the required classes aren't always in the same
  // position (some validators reject predictable prefixes).
  for (let i = chars.length - 1; i > 0; i--) {
    const bytes = new Uint8Array(1)
    crypto.getRandomValues(bytes)
    const j = bytes[0] % (i + 1)
    ;[chars[i], chars[j]] = [chars[j], chars[i]]
  }
  return chars.join('')
}

// TC-011: process-outbox must reject forged JWTs. Kong/gateway JWT verification
// must stay enabled in every deployed environment; this helper is defense in
// depth for direct function invocation (local `functions serve`, misconfigured
// gateway). Local GoTrue issues ES256 user JWTs (JWKS); legacy
// service_role/anon keys remain HS256 — verifyBearerJwt covers both.
function base64UrlToBytes(input: string): Uint8Array {
  const base64 = input.replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
  const binary = atob(padded)
  const out = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i)
  return out
}

function bytesToBase64Url(bytes: ArrayBuffer): string {
  const bin = String.fromCharCode(...new Uint8Array(bytes))
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

// Constant-time string compare (Clara L14): a plain `!==` on the computed
// vs. provided HS256 signature short-circuits on the first differing byte,
// which is a textbook timing side-channel for a MAC check. Walks the full
// max length of both inputs regardless of where they first differ, and
// folds a length mismatch into the same accumulator instead of returning
// early on it.
export function constantTimeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a)
  const bBytes = new TextEncoder().encode(b)
  const len = Math.max(aBytes.length, bBytes.length)
  let diff = aBytes.length ^ bBytes.length
  for (let i = 0; i < len; i++) {
    const av = i < aBytes.length ? aBytes[i] : 0
    const bv = i < bBytes.length ? bBytes[i] : 0
    diff |= av ^ bv
  }
  return diff === 0
}

/** Clock skew leeway for exp/nbf checks (seconds). Documented for M9. */
export const JWT_EXP_LEEWAY_SECONDS = 5

/**
 * Reject payloads with missing or past `exp` (and future `nbf` if present).
 * Applied after signature verify on both HS256 and ES256 paths (Clara M9).
 */
export function assertJwtFresh(
  payload: Record<string, unknown>,
  nowSec: number = Math.floor(Date.now() / 1000),
): void {
  const exp = payload.exp
  if (typeof exp !== 'number' || !Number.isFinite(exp)) {
    throw new Error('JWT missing exp')
  }
  if (exp < nowSec - JWT_EXP_LEEWAY_SECONDS) {
    throw new Error('JWT expired')
  }
  const nbf = payload.nbf
  if (typeof nbf === 'number' && Number.isFinite(nbf)) {
    if (nbf > nowSec + JWT_EXP_LEEWAY_SECONDS) {
      throw new Error('JWT not yet valid')
    }
  }
}

export async function verifyHs256Jwt(
  token: string,
  secret: string,
): Promise<Record<string, unknown>> {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('not a JWT')
  const [headerB64, payloadB64, signatureB64] = parts
  const headerJson = new TextDecoder().decode(base64UrlToBytes(headerB64))
  const header = JSON.parse(headerJson) as { alg?: string; typ?: string }
  if (header.alg !== 'HS256') throw new Error('unsupported JWT alg')

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`)
  const expected = bytesToBase64Url(await crypto.subtle.sign('HMAC', key, data))
  if (!constantTimeEqual(expected, signatureB64)) throw new Error('bad JWT signature')
  const payload = JSON.parse(new TextDecoder().decode(base64UrlToBytes(payloadB64))) as Record<
    string,
    unknown
  >
  assertJwtFresh(payload)
  return payload
}

export function jwtSecretFromEnv(env: { get(key: string): string | undefined }): string {
  const secret = env.get('JWT_SECRET') || env.get('SUPABASE_JWT_SECRET')
  if (!secret) throw new Error('JWT secret not configured')
  return secret
}

export type JwtVerifyEnv = {
  get(key: string): string | undefined
}

// Fetches GoTrue's JWKS once per isolate. Used for ES256 user access tokens.
let cachedJwks: { keys: JsonWebKey[] } | null = null

async function fetchJwks(env: JwtVerifyEnv): Promise<{ keys: JsonWebKey[] }> {
  if (cachedJwks) return cachedJwks
  const base =
    env.get('SUPABASE_URL') ||
    env.get('API_URL') ||
    'http://127.0.0.1:54321'
  const res = await fetch(`${base.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`)
  if (!res.ok) throw new Error(`jwks fetch failed: ${res.status}`)
  cachedJwks = (await res.json()) as { keys: JsonWebKey[] }
  return cachedJwks
}

/** Reset JWKS cache (tests only). */
export function resetJwksCacheForTests(): void {
  cachedJwks = null
}

/** Inject JWKS for tests (skips network fetch). */
export function setJwksForTests(jwks: { keys: JsonWebKey[] }): void {
  cachedJwks = jwks
}

async function verifyEs256Jwt(
  token: string,
  header: { alg?: string; kid?: string },
  headerB64: string,
  payloadB64: string,
  signatureB64: string,
  env: JwtVerifyEnv,
): Promise<Record<string, unknown>> {
  const jwks = await fetchJwks(env)
  if (!header.kid) throw new Error('JWT missing kid')
  const jwk = jwks.keys.find((k) => (k as { kid?: string }).kid === header.kid)
  if (!jwk) throw new Error('unknown JWT kid')
  const key = await crypto.subtle.importKey(
    'jwk',
    { ...jwk, key_ops: ['verify'], ext: true },
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify'],
  )
  const sigBytes = base64UrlToBytes(signatureB64)
  const sigCopy = new Uint8Array(sigBytes.byteLength)
  sigCopy.set(sigBytes)
  const ok = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    sigCopy,
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  )
  if (!ok) throw new Error('bad JWT signature')
  const payload = JSON.parse(new TextDecoder().decode(base64UrlToBytes(payloadB64))) as Record<
    string,
    unknown
  >
  assertJwtFresh(payload)
  return payload
}

/**
 * Verify a bearer JWT for process-outbox defense-in-depth.
 * - HS256 (legacy service_role / anon): project JWT_SECRET
 * - ES256 (GoTrue user access tokens): JWKS at SUPABASE_URL/auth/v1/.well-known/jwks.json
 * - Both paths require a numeric `exp` that is not in the past (JWT_EXP_LEEWAY_SECONDS
 *   skew). Unknown ES256 `kid` is rejected — no fallback to jwks.keys[0] (Clara M9 / L13).
 */
export async function verifyBearerJwt(
  token: string,
  env: JwtVerifyEnv,
): Promise<Record<string, unknown>> {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('not a JWT')
  const [headerB64, payloadB64, signatureB64] = parts
  const header = JSON.parse(new TextDecoder().decode(base64UrlToBytes(headerB64))) as {
    alg?: string
    kid?: string
    typ?: string
  }
  if (header.alg === 'HS256') {
    return verifyHs256Jwt(token, jwtSecretFromEnv(env))
  }
  if (header.alg === 'ES256') {
    return verifyEs256Jwt(token, header, headerB64, payloadB64, signatureB64, env)
  }
  throw new Error(`unsupported JWT alg: ${header.alg ?? 'missing'}`)
}
