// APP-01: shared pieces of the patient sign-in-code flow
// (patient-request-login-code / patient-verify-login-code / delete-account
// re-auth). Pure helpers plus one small orchestration, mintSessionForUser,
// which takes its clients as parameters so it can be unit tested with fakes.
//
// Policy, matching the demo build's sign-in spec: 6 digits, 10 minutes,
// single use, 5 wrong tries lock the email for 15 minutes. The policy itself
// is enforced in SQL (redeem_patient_login_code), these constants only feed
// it.

export const LOGIN_CODE_TTL_SECONDS = 10 * 60
export const LOGIN_CODE_MAX_ATTEMPTS = 5
export const LOGIN_CODE_LOCK_SECONDS = 15 * 60

const SIX_DIGITS = /^\d{6}$/

export function isLoginCode(value: unknown): value is string {
  return typeof value === 'string' && SIX_DIGITS.test(value)
}

// Uniform over 000000-999999: rejection-sample a 32-bit value so the modulo
// doesn't favour low codes (2^32 isn't a multiple of 10^6).
export function generateLoginCode(
  fill: (buf: Uint32Array) => Uint32Array = (buf) => crypto.getRandomValues(buf),
): string {
  const limit = Math.floor(0x1_0000_0000 / 1_000_000) * 1_000_000
  const buf = new Uint32Array(1)
  for (;;) {
    fill(buf)
    if (buf[0] < limit) return String(buf[0] % 1_000_000).padStart(6, '0')
  }
}

export type RedeemOutcome =
  | { result: 'ok'; userId: string }
  | { result: 'invalid' }
  | { result: 'expired' }
  | { result: 'locked'; retryAfterSeconds: number }

// Reads redeem_patient_login_code()'s jsonb. Anything unexpected is treated
// as a failed try, never as success.
export function parseRedeemResult(data: unknown): RedeemOutcome {
  if (!data || typeof data !== 'object') return { result: 'invalid' }
  const row = data as Record<string, unknown>
  switch (row.result) {
    case 'ok':
      return typeof row.user_id === 'string' && row.user_id.length > 0
        ? { result: 'ok', userId: row.user_id }
        : { result: 'invalid' }
    case 'expired':
      return { result: 'expired' }
    case 'locked': {
      const n = Number(row.retry_after_seconds)
      return {
        result: 'locked',
        retryAfterSeconds: Number.isFinite(n) && n > 0 ? Math.ceil(n) : LOGIN_CODE_LOCK_SECONDS,
      }
    }
    default:
      return { result: 'invalid' }
  }
}

// HTTP shape for a failed redeem. The app maps these codes to copy:
// invalid_code -> "That code isn't right", code_expired -> "That code has
// expired", locked -> "Too many attempts. Try again in {n} min".
export function redeemFailureResponse(
  outcome: Exclude<RedeemOutcome, { result: 'ok' }>,
): { status: number; body: Record<string, unknown> } {
  switch (outcome.result) {
    case 'expired':
      return { status: 401, body: { error: 'code_expired' } }
    case 'locked':
      return {
        status: 429,
        body: { error: 'locked', retry_after_seconds: outcome.retryAfterSeconds },
      }
    default:
      return { status: 401, body: { error: 'invalid_code' } }
  }
}

export interface PatientSession {
  access_token: string
  refresh_token: string
  expires_in: number
  token_type: string
  user: { id: string; email: string | null }
}

// Minimal surfaces of the two supabase-js clients this needs.
export interface GenerateLinkClient {
  auth: {
    admin: {
      generateLink(params: { type: 'magiclink'; email: string }): Promise<{
        data: { properties?: { hashed_token?: string } | null; user?: { id: string } | null } | null
        error: unknown
      }>
    }
  }
}

export interface VerifyOtpClient {
  auth: {
    verifyOtp(params: { token_hash: string; type: 'magiclink' }): Promise<{
      data: {
        session: {
          access_token: string
          refresh_token: string
          expires_in: number
          token_type: string
          user: { id: string; email?: string | null }
        } | null
      } | null
      error: unknown
    }>
  }
}

export class SessionMintError extends Error {}

// Turns a code we already verified into a real GoTrue session. The admin
// API issues a single-use magic-link token_hash (no email is sent by
// generateLink), which we redeem at once, server-side, with a throwaway
// anon client. The token_hash never leaves this function, so the only way
// in from outside is still our rate-limited, lockout-protected code.
// The user id is re-checked so a token minted for one account can never
// sign in another.
export async function mintSessionForUser(
  admin: GenerateLinkClient,
  verifier: VerifyOtpClient,
  params: { userId: string; email: string },
): Promise<PatientSession> {
  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: params.email,
  })
  const tokenHash = link?.properties?.hashed_token
  if (linkError || !tokenHash) throw new SessionMintError('generateLink failed')
  if (link?.user?.id && link.user.id !== params.userId) {
    throw new SessionMintError('generateLink returned a different user')
  }

  const { data: verified, error: verifyError } = await verifier.auth.verifyOtp({
    token_hash: tokenHash,
    type: 'magiclink',
  })
  const session = verified?.session
  if (verifyError || !session?.access_token || !session.refresh_token) {
    throw new SessionMintError('verifyOtp failed')
  }
  if (session.user.id !== params.userId) {
    throw new SessionMintError('session is for a different user')
  }

  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in,
    token_type: session.token_type ?? 'bearer',
    user: { id: session.user.id, email: session.user.email ?? null },
  }
}
