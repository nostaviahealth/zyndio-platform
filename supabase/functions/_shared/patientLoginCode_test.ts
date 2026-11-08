import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  type GenerateLinkClient,
  LOGIN_CODE_LOCK_SECONDS,
  SessionMintError,
  type VerifyOtpClient,
  generateLoginCode,
  isLoginCode,
  mintSessionForUser,
  parseRedeemResult,
  redeemFailureResponse,
} from './patientLoginCode.ts'

Deno.test('isLoginCode accepts exactly six digits', () => {
  assert(isLoginCode('000000'))
  assert(isLoginCode('482913'))
  assert(!isLoginCode('48291'))
  assert(!isLoginCode('4829130'))
  assert(!isLoginCode('48a913'))
  assert(!isLoginCode(' 482913'))
  assert(!isLoginCode(482913))
  assert(!isLoginCode(null))
})

Deno.test('generateLoginCode always returns six digits, zero-padded', () => {
  for (let i = 0; i < 500; i++) assert(isLoginCode(generateLoginCode()))
  const fixed = (v: number) => (buf: Uint32Array) => {
    buf[0] = v
    return buf
  }
  assertEquals(generateLoginCode(fixed(7)), '000007')
  assertEquals(generateLoginCode(fixed(1_000_007)), '000007')
})

Deno.test('generateLoginCode rejects the biased tail of the 32-bit range', () => {
  // 4294967295 is above the largest multiple of 10^6 below 2^32, so it must
  // be redrawn rather than folded onto a low code.
  const draws = [0xffff_ffff, 123_456]
  let calls = 0
  const code = generateLoginCode((buf) => {
    buf[0] = draws[calls++]
    return buf
  })
  assertEquals(code, '123456')
  assertEquals(calls, 2)
})

Deno.test('parseRedeemResult maps every SQL result and never invents success', () => {
  assertEquals(parseRedeemResult({ result: 'ok', user_id: 'u-1' }), { result: 'ok', userId: 'u-1' })
  assertEquals(parseRedeemResult({ result: 'ok' }), { result: 'invalid' })
  assertEquals(parseRedeemResult({ result: 'ok', user_id: '' }), { result: 'invalid' })
  assertEquals(parseRedeemResult({ result: 'expired' }), { result: 'expired' })
  assertEquals(parseRedeemResult({ result: 'locked', retry_after_seconds: 61.2 }), {
    result: 'locked',
    retryAfterSeconds: 62,
  })
  assertEquals(parseRedeemResult({ result: 'locked' }), {
    result: 'locked',
    retryAfterSeconds: LOGIN_CODE_LOCK_SECONDS,
  })
  assertEquals(parseRedeemResult({ result: 'invalid' }), { result: 'invalid' })
  assertEquals(parseRedeemResult({ result: 'weird' }), { result: 'invalid' })
  assertEquals(parseRedeemResult(null), { result: 'invalid' })
  assertEquals(parseRedeemResult('ok'), { result: 'invalid' })
})

Deno.test('redeemFailureResponse: invalid/expired are 401, locked is 429 with time left', () => {
  assertEquals(redeemFailureResponse({ result: 'invalid' }), { status: 401, body: { error: 'invalid_code' } })
  assertEquals(redeemFailureResponse({ result: 'expired' }), { status: 401, body: { error: 'code_expired' } })
  assertEquals(redeemFailureResponse({ result: 'locked', retryAfterSeconds: 840 }), {
    status: 429,
    body: { error: 'locked', retry_after_seconds: 840 },
  })
})

function fakeAdmin(result: { hashed_token?: string; userId?: string; error?: unknown }) {
  const calls: unknown[] = []
  const admin: GenerateLinkClient = {
    auth: {
      admin: {
        generateLink(params) {
          calls.push(params)
          return Promise.resolve({
            data: { properties: { hashed_token: result.hashed_token }, user: result.userId ? { id: result.userId } : null },
            error: result.error ?? null,
          })
        },
      },
    },
  }
  return { admin, calls }
}

function fakeVerifier(sessionUserId: string | null, error: unknown = null) {
  const calls: unknown[] = []
  const verifier: VerifyOtpClient = {
    auth: {
      verifyOtp(params) {
        calls.push(params)
        return Promise.resolve({
          data: {
            session: sessionUserId
              ? {
                access_token: 'at',
                refresh_token: 'rt',
                expires_in: 900,
                token_type: 'bearer',
                user: { id: sessionUserId, email: 'patient@example.test' },
              }
              : null,
          },
          error,
        })
      },
    },
  }
  return { verifier, calls }
}

Deno.test('mintSessionForUser redeems the magic-link hash server-side and returns tokens', async () => {
  const { admin, calls: linkCalls } = fakeAdmin({ hashed_token: 'th-1', userId: 'u-1' })
  const { verifier, calls: verifyCalls } = fakeVerifier('u-1')
  const session = await mintSessionForUser(admin, verifier, { userId: 'u-1', email: 'patient@example.test' })
  assertEquals(linkCalls, [{ type: 'magiclink', email: 'patient@example.test' }])
  assertEquals(verifyCalls, [{ token_hash: 'th-1', type: 'magiclink' }])
  assertEquals(session, {
    access_token: 'at',
    refresh_token: 'rt',
    expires_in: 900,
    token_type: 'bearer',
    user: { id: 'u-1', email: 'patient@example.test' },
  })
})

Deno.test('mintSessionForUser refuses when generateLink fails or returns no hash', async () => {
  const { verifier, calls } = fakeVerifier('u-1')
  await assertRejects(
    () => mintSessionForUser(fakeAdmin({ error: new Error('x') }).admin, verifier, { userId: 'u-1', email: 'e@example.test' }),
    SessionMintError,
  )
  await assertRejects(
    () => mintSessionForUser(fakeAdmin({}).admin, verifier, { userId: 'u-1', email: 'e@example.test' }),
    SessionMintError,
  )
  assertEquals(calls.length, 0, 'nothing is verified without a hash')
})

Deno.test('mintSessionForUser never signs in a different account than the code was for', async () => {
  await assertRejects(
    () =>
      mintSessionForUser(fakeAdmin({ hashed_token: 'th', userId: 'u-other' }).admin, fakeVerifier('u-other').verifier, {
        userId: 'u-1',
        email: 'e@example.test',
      }),
    SessionMintError,
  )
  await assertRejects(
    () =>
      mintSessionForUser(fakeAdmin({ hashed_token: 'th' }).admin, fakeVerifier('u-other').verifier, {
        userId: 'u-1',
        email: 'e@example.test',
      }),
    SessionMintError,
  )
})

Deno.test('mintSessionForUser refuses when verifyOtp fails', async () => {
  await assertRejects(
    () =>
      mintSessionForUser(fakeAdmin({ hashed_token: 'th', userId: 'u-1' }).admin, fakeVerifier(null, new Error('bad')).verifier, {
        userId: 'u-1',
        email: 'e@example.test',
      }),
    SessionMintError,
  )
})
