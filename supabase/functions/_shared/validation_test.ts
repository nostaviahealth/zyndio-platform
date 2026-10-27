import { assert, assertEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  MIN_PASSWORD_LENGTH,
  decodeJwtPayload,
  generatePlaceholderPassword,
  generateToken,
  hasAal2Claim,
  hashTokenHex,
  isPasswordLongEnough,
  isValidAppRole,
  isValidEmail,
  isValidUuid,
  normalizeEmail,
  parseBearerToken,
  verifyHs256Jwt,
  verifyBearerJwt,
} from './validation.ts'

Deno.test('normalizeEmail trims and lowercases', () => {
  assertEquals(normalizeEmail('  Alice@Example.Test '), 'alice@example.test')
})

Deno.test('normalizeEmail rejects non-strings and empty input', () => {
  assertEquals(normalizeEmail(42), null)
  assertEquals(normalizeEmail('   '), null)
  assertEquals(normalizeEmail(null), null)
})

Deno.test('isValidEmail accepts a plausible address and rejects garbage', () => {
  assert(isValidEmail('bob@example.test'))
  assert(!isValidEmail('not-an-email'))
  assert(!isValidEmail(123))
})

Deno.test('isValidAppRole only accepts the four known roles', () => {
  assert(isValidAppRole('org_admin'))
  assert(isValidAppRole('physician'))
  assert(isValidAppRole('care_coordinator'))
  assert(isValidAppRole('read_only'))
  assert(!isValidAppRole('super_admin'))
  assert(!isValidAppRole(''))
  assert(!isValidAppRole(undefined))
})

Deno.test('isValidUuid accepts a v4-shaped uuid and rejects near-misses', () => {
  assert(isValidUuid('123e4567-e89b-12d3-a456-426614174000'))
  assert(!isValidUuid('123e4567e89b12d3a456426614174000'))
  assert(!isValidUuid('not-a-uuid'))
  assert(!isValidUuid(null))
})

Deno.test('isPasswordLongEnough enforces the minimum length with no composition rules', () => {
  assertEquals(MIN_PASSWORD_LENGTH, 12)
  assert(isPasswordLongEnough('x'.repeat(12)))
  assert(!isPasswordLongEnough('x'.repeat(11)))
  assert(!isPasswordLongEnough(12345678901))
})

Deno.test('parseBearerToken extracts the token, case-insensitively, and rejects malformed headers', () => {
  assertEquals(parseBearerToken('Bearer abc.def.ghi'), 'abc.def.ghi')
  assertEquals(parseBearerToken('bearer   abc.def.ghi  '), 'abc.def.ghi')
  assertEquals(parseBearerToken('Basic abc'), null)
  assertEquals(parseBearerToken(null), null)
  assertEquals(parseBearerToken(undefined), null)
})

Deno.test('decodeJwtPayload decodes a base64url JWT payload without verifying the signature', () => {
  const payload = { sub: 'user-1', aal: 'aal2' }
  const base64url = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  const token = `${base64url({ alg: 'HS256' })}.${base64url(payload)}.signature-not-checked`
  assertEquals(decodeJwtPayload(token), payload)
})

Deno.test('decodeJwtPayload throws on a non-JWT string', () => {
  assertThrows(() => decodeJwtPayload('not-a-jwt'))
})

Deno.test('hasAal2Claim is true only for the exact string aal2', () => {
  assert(hasAal2Claim({ aal: 'aal2' }))
  assert(!hasAal2Claim({ aal: 'aal1' }))
  assert(!hasAal2Claim({}))
  assert(!hasAal2Claim({ aal: 2 }))
})

Deno.test('generateToken produces 64 hex characters (32 random bytes) and varies per call', () => {
  const a = generateToken()
  const b = generateToken()
  assertEquals(a.length, 64)
  assert(/^[0-9a-f]+$/.test(a))
  assert(a !== b)
})

Deno.test('generatePlaceholderPassword always satisfies lower_upper_letters_digits_symbols and length >= 12, and varies per call', () => {
  const a = generatePlaceholderPassword()
  const b = generatePlaceholderPassword()
  assert(a.length >= MIN_PASSWORD_LENGTH)
  assert(/[a-z]/.test(a))
  assert(/[A-Z]/.test(a))
  assert(/[0-9]/.test(a))
  assert(/[^a-zA-Z0-9]/.test(a))
  assert(a !== b)
})

Deno.test('hashTokenHex is deterministic and sensitive to its input', async () => {
  const hashA = await hashTokenHex('token-a')
  const hashAgain = await hashTokenHex('token-a')
  const hashB = await hashTokenHex('token-b')
  assertEquals(hashA, hashAgain)
  assert(hashA !== hashB)
  assertEquals(hashA.length, 64)
})

Deno.test('verifyHs256Jwt accepts a correctly signed HS256 token', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const payload = btoa(JSON.stringify({ role: 'service_role', sub: 'worker' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sigBuf = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const decoded = await verifyHs256Jwt(`${header}.${payload}.${sig}`, secret)
  assertEquals(decoded.role, 'service_role')
})

Deno.test('verifyHs256Jwt rejects a token with a bad signature (TC-011)', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const payload = btoa(JSON.stringify({ role: 'service_role' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  await assertRejects(
    () => verifyHs256Jwt(`${header}.${payload}.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`, secret),
    Error,
    'bad JWT signature',
  )
})

Deno.test('verifyBearerJwt accepts HS256 via JWT_SECRET env (TC-011)', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const payload = btoa(JSON.stringify({ role: 'authenticated', sub: 'user-1' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sigBuf = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const env = { get: (k: string) => (k === 'JWT_SECRET' ? secret : undefined) }
  const decoded = await verifyBearerJwt(`${header}.${payload}.${sig}`, env)
  assertEquals(decoded.role, 'authenticated')
})

Deno.test('verifyBearerJwt rejects unsupported alg (TC-011)', async () => {
  const header = btoa(JSON.stringify({ alg: 'none', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const payload = btoa(JSON.stringify({ role: 'service_role' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const env = { get: (_k: string) => undefined }
  await assertRejects(
    () => verifyBearerJwt(`${header}.${payload}.x`, env),
    Error,
    'unsupported JWT alg',
  )
})
