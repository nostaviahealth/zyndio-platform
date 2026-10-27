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
// gateway). Verifies HS256 with the project JWT secret.
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
  if (expected !== signatureB64) throw new Error('bad JWT signature')
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(payloadB64))) as Record<
    string,
    unknown
  >
}

export function jwtSecretFromEnv(env: { get(key: string): string | undefined }): string {
  const secret = env.get('JWT_SECRET') || env.get('SUPABASE_JWT_SECRET')
  if (!secret) throw new Error('JWT secret not configured')
  return secret
}
