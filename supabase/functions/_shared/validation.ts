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
