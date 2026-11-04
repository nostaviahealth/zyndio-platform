// APP-01: step 2 of patient sign-in. Public (no session): email + 6-digit
// code in, session tokens out (same response shape as patient-login, so the
// app stores it with setSession exactly the same way).
//
// redeem_patient_login_code() owns the policy atomically: 10-minute expiry,
// single use, 5 wrong tries -> 15-minute lock. On top of that, a per-IP
// failure throttle (like patient-login's PSU-RL-03) stops one client
// spraying guesses across many emails. Unknown, staff and real patient
// emails all fail identically.
//
// The session is minted server-side (mintSessionForUser): a GoTrue OTP that a
// client could verify directly would bypass both limits above.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { MAX_EMAIL_LENGTH, isValidEmail, normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'
import {
  LOGIN_CODE_LOCK_SECONDS,
  LOGIN_CODE_MAX_ATTEMPTS,
  isLoginCode,
  mintSessionForUser,
  parseRedeemResult,
  redeemFailureResponse,
} from '../_shared/patientLoginCode.ts'

const VERIFY_IP_FAIL_LIMIT = 30
const VERIFY_IP_WINDOW_SECONDS = 15 * 60
const PAD_MS = 300

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const code = typeof body.code === 'string' ? body.code.trim() : ''
    // A malformed entry never reaches redeem, so it can't spend a try (the
    // app also checks this before sending).
    if (!email || email.length > MAX_EMAIL_LENGTH || !isValidEmail(email) || !isLoginCode(code)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const ipKey = await sha256Hex(clientIpFrom(req))
    const { data: ipAllowed } = await admin.rpc('peek_rate_limit', {
      p_bucket: 'patient_login_code_verify_ip',
      p_key_hash: ipKey,
      p_limit: VERIFY_IP_FAIL_LIMIT,
      p_window_seconds: VERIFY_IP_WINDOW_SECONDS,
    })
    if (ipAllowed === false) {
      await writeAuditLog(admin, {
        eventType: 'patient_login_code_ip_rate_limited',
        actorUserId: null,
        targetUserId: null,
        orgId: null,
        metadata: { ip_hash: ipKey.slice(0, 12) },
      })
      await padTimingTo(startedAt, PAD_MS)
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const { data: redeemData, error: redeemError } = await admin.rpc('redeem_patient_login_code', {
      p_email: email,
      p_code: code,
      p_max_attempts: LOGIN_CODE_MAX_ATTEMPTS,
      p_lock_seconds: LOGIN_CODE_LOCK_SECONDS,
    })
    if (redeemError) {
      console.error('patient-verify-login-code: redeem failed', { code: redeemError.code })
      await padTimingTo(startedAt, PAD_MS)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    const outcome = parseRedeemResult(redeemData)
    if (outcome.result !== 'ok') {
      await admin.rpc('check_and_consume_rate_limit', {
        p_bucket: 'patient_login_code_verify_ip',
        p_key_hash: ipKey,
        p_limit: VERIFY_IP_FAIL_LIMIT,
        p_window_seconds: VERIFY_IP_WINDOW_SECONDS,
      })
      await writeAuditLog(admin, {
        eventType: 'patient_login_code_failed',
        actorUserId: null,
        targetUserId: null,
        orgId: null,
        metadata: { ip_hash: ipKey.slice(0, 12), result: outcome.result },
      })
      const failure = redeemFailureResponse(outcome)
      await padTimingTo(startedAt, PAD_MS)
      return jsonResponse(req, failure.body, failure.status)
    }

    const verifier = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )
    const session = await mintSessionForUser(admin, verifier, { userId: outcome.userId, email })

    await writeAuditLog(admin, {
      eventType: 'patient_login_code_ok',
      actorUserId: outcome.userId,
      targetUserId: outcome.userId,
      orgId: null,
      metadata: {},
    })
    await padTimingTo(startedAt, PAD_MS)
    return jsonResponse(req, { status: 'ok', ...session })
  } catch (err) {
    console.error('patient-verify-login-code error', err instanceof Error ? err.message : 'unknown')
    await padTimingTo(startedAt, PAD_MS)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
