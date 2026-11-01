import { assert, assertEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  JWT_EXP_LEEWAY_SECONDS,
  MAX_EMAIL_LENGTH,
  MAX_MRN_LENGTH,
  MIN_PASSWORD_LENGTH,
  assertJwtFresh,
  constantTimeEqual,
  decodeJwtPayload,
  declaredBodyTooLarge,
  actualBodyTooLarge,
  parseJsonObject,
  generatePlaceholderPassword,
  generateToken,
  hasAal2Claim,
  hashTokenHex,
  isPasswordLongEnough,
  isValidAppRole,
  canGrantRole,
  normalizeFullName,
  isValidEmail,
  isValidUuid,
  normalizeEmail,
  parseBearerToken,
  resetJwksCacheForTests,
  setJwksForTests,
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
  const exp = Math.floor(Date.now() / 1000) + 600
  const payload = btoa(JSON.stringify({ role: 'service_role', sub: 'worker', exp }))
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

// --- Clara L14: constant-time HS256 signature compare ---

Deno.test('constantTimeEqual accepts equal strings and rejects any single differing byte', () => {
  const a = 'abcdefghijklmnopqrstuvwxyz0123456789'
  assert(constantTimeEqual(a, a.slice()))
  assert(!constantTimeEqual(a, 'Xbcdefghijklmnopqrstuvwxyz0123456789'))
  assert(!constantTimeEqual(a, 'abcdefghijklmnopqrstuvwxyz012345678X'))
  assert(!constantTimeEqual(a, 'abcdefghijklmnopXrstuvwxyz0123456789'))
})

Deno.test('constantTimeEqual rejects a length mismatch instead of throwing', () => {
  assert(!constantTimeEqual('short', 'short-but-longer'))
  assert(!constantTimeEqual('short-but-longer', 'short'))
  assert(!constantTimeEqual('', 'a'))
  assert(constantTimeEqual('', ''))
})

Deno.test('verifyHs256Jwt still accepts a correct signature and rejects a same-length tampered one', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const exp = Math.floor(Date.now() / 1000) + 600
  const payload = btoa(JSON.stringify({ role: 'service_role', exp }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${header}.${payload}`))
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const decoded = await verifyHs256Jwt(`${header}.${payload}.${sig}`, secret)
  assertEquals(decoded.role, 'service_role')

  // Flip the signature's last character - same length as a correct
  // signature, so a length-only check would wrongly accept it.
  const lastChar = sig.at(-1) === 'A' ? 'B' : 'A'
  const tampered = sig.slice(0, -1) + lastChar
  await assertRejects(
    () => verifyHs256Jwt(`${header}.${payload}.${tampered}`, secret),
    Error,
    'bad JWT signature',
  )
})

Deno.test('verifyBearerJwt accepts HS256 via JWT_SECRET env (TC-011)', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const exp = Math.floor(Date.now() / 1000) + 600
  const payload = btoa(JSON.stringify({ role: 'authenticated', sub: 'user-1', exp }))
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


// --- Clara M9 / L13: exp required + unknown kid rejected ---

function b64urlJson(obj: unknown): string {
  return btoa(JSON.stringify(obj))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

async function signHs256(secret: string, header: object, claims: object): Promise<string> {
  const headerB64 = b64urlJson(header)
  const payloadB64 = b64urlJson(claims)
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
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  return `${headerB64}.${payloadB64}.${sig}`
}

Deno.test('assertJwtFresh rejects missing exp (TC-011 M9)', () => {
  assertThrows(() => assertJwtFresh({ role: 'service_role' }), Error, 'JWT missing exp')
})

Deno.test('assertJwtFresh rejects expired exp outside leeway (TC-011 M9)', () => {
  const now = 1_700_000_000
  assertThrows(
    () => assertJwtFresh({ exp: now - JWT_EXP_LEEWAY_SECONDS - 1 }, now),
    Error,
    'JWT expired',
  )
})

Deno.test('assertJwtFresh allows exp within leeway (TC-011 M9)', () => {
  const now = 1_700_000_000
  assertJwtFresh({ exp: now - JWT_EXP_LEEWAY_SECONDS }, now)
})

Deno.test('verifyBearerJwt rejects HS256 with missing exp (TC-011 M9)', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const token = await signHs256(secret, { alg: 'HS256', typ: 'JWT' }, { role: 'service_role' })
  const env = { get: (k: string) => (k === 'JWT_SECRET' ? secret : undefined) }
  await assertRejects(() => verifyBearerJwt(token, env), Error, 'JWT missing exp')
})

Deno.test('verifyBearerJwt rejects HS256 with expired exp (TC-011 M9)', async () => {
  const secret = 'test-secret-at-least-32-characters-long!!'
  const exp = Math.floor(Date.now() / 1000) - 60
  const token = await signHs256(secret, { alg: 'HS256', typ: 'JWT' }, { role: 'service_role', exp })
  const env = { get: (k: string) => (k === 'JWT_SECRET' ? secret : undefined) }
  await assertRejects(() => verifyBearerJwt(token, env), Error, 'JWT expired')
})

Deno.test('verifyBearerJwt accepts valid ES256 and rejects unknown kid (TC-011 M9)', async () => {
  resetJwksCacheForTests()
  const pair = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  )
  const publicJwk = await crypto.subtle.exportKey('jwk', pair.publicKey) as JsonWebKey & {
    kid?: string
  }
  publicJwk.kid = 'test-kid-m9'
  publicJwk.alg = 'ES256'
  publicJwk.use = 'sig'
  setJwksForTests({ keys: [publicJwk] })

  const exp = Math.floor(Date.now() / 1000) + 600
  const headerB64 = b64urlJson({ alg: 'ES256', typ: 'JWT', kid: 'test-kid-m9' })
  const payloadB64 = b64urlJson({ role: 'authenticated', sub: 'es-user', exp })
  const sigBuf = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    pair.privateKey,
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const env = { get: (_k: string) => undefined }
  const decoded = await verifyBearerJwt(`${headerB64}.${payloadB64}.${sig}`, env)
  assertEquals(decoded.sub, 'es-user')

  // Unknown kid must not fall back to keys[0]
  const badHeader = b64urlJson({ alg: 'ES256', typ: 'JWT', kid: 'not-this-kid' })
  const badSigBuf = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    pair.privateKey,
    new TextEncoder().encode(`${badHeader}.${payloadB64}`),
  )
  const badSig = btoa(String.fromCharCode(...new Uint8Array(badSigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  await assertRejects(
    () => verifyBearerJwt(`${badHeader}.${payloadB64}.${badSig}`, env),
    Error,
    'unknown JWT kid',
  )
  resetJwksCacheForTests()
})

Deno.test('verifyBearerJwt rejects ES256 with expired exp (TC-011 M9)', async () => {
  resetJwksCacheForTests()
  const pair = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  )
  const publicJwk = await crypto.subtle.exportKey('jwk', pair.publicKey) as JsonWebKey & {
    kid?: string
  }
  publicJwk.kid = 'test-kid-exp'
  setJwksForTests({ keys: [publicJwk] })

  const exp = Math.floor(Date.now() / 1000) - 120
  const headerB64 = b64urlJson({ alg: 'ES256', typ: 'JWT', kid: 'test-kid-exp' })
  const payloadB64 = b64urlJson({ role: 'authenticated', sub: 'es-user', exp })
  const sigBuf = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    pair.privateKey,
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  const env = { get: (_k: string) => undefined }
  await assertRejects(
    () => verifyBearerJwt(`${headerB64}.${payloadB64}.${sig}`, env),
    Error,
    'JWT expired',
  )
  resetJwksCacheForTests()
})

Deno.test('canGrantRole follows org_admin > physician > care_coordinator > read_only', () => {
  assert(canGrantRole('org_admin', 'org_admin'))
  assert(canGrantRole('org_admin', 'read_only'))
  assert(!canGrantRole('physician', 'org_admin'))
  assert(canGrantRole('physician', 'physician'))
  assert(canGrantRole('physician', 'read_only'))
  assert(!canGrantRole('care_coordinator', 'physician'))
  assert(!canGrantRole('read_only', 'care_coordinator'))
})

Deno.test('normalizeFullName trims, collapses whitespace, rejects empty/oversized', () => {
  assertEquals(normalizeFullName('  Alex   Lindgren '), 'Alex Lindgren')
  assertEquals(normalizeFullName(''), null)
  assertEquals(normalizeFullName('   '), null)
  assertEquals(normalizeFullName(null), null)
  assertEquals(normalizeFullName('x'.repeat(201)), null)
  assertEquals(normalizeFullName('x'.repeat(200)), 'x'.repeat(200))
})

// --- TC-018 (Henry's calls, 1 Nov 2026; Clara PR #23 review findings #2/#6):
// create-patient length caps + request body size limit ---

Deno.test('MAX_MRN_LENGTH and MAX_EMAIL_LENGTH are the agreed caps', () => {
  assertEquals(MAX_MRN_LENGTH, 64)
  assertEquals(MAX_EMAIL_LENGTH, 254)
})

Deno.test('declaredBodyTooLarge reads Content-Length before anything is read', () => {
  const reqWithLength = (n: number) =>
    new Request('http://local/create-patient', {
      method: 'POST',
      headers: { 'content-length': String(n) },
      body: 'x',
    })
  assert(declaredBodyTooLarge(reqWithLength(20_000_000), 8192))
  assert(!declaredBodyTooLarge(reqWithLength(100), 8192))
  // No header at all (e.g. chunked transfer) - can't tell from the header
  // alone, so this must not itself reject; actualBodyTooLarge is the
  // backstop once the body is actually read.
  const noHeader = new Request('http://local/create-patient', { method: 'POST' })
  assert(!declaredBodyTooLarge(noHeader, 8192))
})

Deno.test('actualBodyTooLarge measures real UTF-8 byte length, not JS string length', () => {
  assert(!actualBodyTooLarge('x'.repeat(8192), 8192))
  assert(actualBodyTooLarge('x'.repeat(8193), 8192))
  // Multi-byte characters: 4096 chars of a 3-byte-each symbol is 12288 bytes,
  // well over an 8192 cap, even though the JS string length is only 4096.
  assert(actualBodyTooLarge('€'.repeat(4096), 8192))
})

// --- TC-018 (Henry's calls, 1 Nov 2026; Clara PR #23 review finding #6):
// a null/non-object create-patient body must be a 400, not an uncaught
// TypeError (-> 500) the first time the handler reads body.email ---

Deno.test('parseJsonObject accepts a plain JSON object', () => {
  assertEquals(parseJsonObject('{"email":"a@example.test"}'), { ok: true, body: { email: 'a@example.test' } })
})

Deno.test('parseJsonObject treats an empty body as an empty object (unchanged prior behaviour)', () => {
  assertEquals(parseJsonObject(''), { ok: true, body: {} })
})

for (const [label, raw] of [
  ['the literal null', 'null'],
  ['an array', '[]'],
  ['a string', '"hi"'],
  ['a number', '42'],
  ['a boolean', 'true'],
  ['invalid JSON', '{not valid'],
] as const) {
  Deno.test(`parseJsonObject rejects ${label}`, () => {
    assertEquals(parseJsonObject(raw), { ok: false })
  })
}
