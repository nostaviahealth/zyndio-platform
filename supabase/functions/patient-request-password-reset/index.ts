// TC-012 slice 1: request a password-reset link (1h TTL, Henry 27 Oct).
// Public (no session). PSU-ENUM-03: identical "if an account exists, we
// sent mail" response and timing for a known vs unknown email - only the
// real owner's mailbox (outbox stub) ever gets a token.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import { generateToken, hashTokenHex, isValidEmail, normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'

const RESET_IP_LIMIT = 10
const RESET_EMAIL_LIMIT = 5
const RESET_WINDOW_SECONDS = 15 * 60

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)

    if (!email || !isValidEmail(email)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const ip = clientIpFrom(req)
    const { data: ipAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_reset_ip',
      p_key_hash: await sha256Hex(ip),
      p_limit: RESET_IP_LIMIT,
      p_window_seconds: RESET_WINDOW_SECONDS,
    })
    const { data: emailAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_reset_email',
      p_key_hash: await sha256Hex(email),
      p_limit: RESET_EMAIL_LIMIT,
      p_window_seconds: RESET_WINDOW_SECONDS,
    })
    if (ipAllowed === false || emailAllowed === false) {
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const { data: userId } = await admin.rpc('find_user_id_by_email', { p_email: email })

    if (userId) {
      const token = generateToken()
      const tokenHash = await hashTokenHex(token)
      const { error: insertError } = await admin
        .from('patient_password_resets')
        .insert({ user_id: userId, token_hash: tokenHash })
      if (insertError) {
        console.error('patient-request-password-reset: insert failed', insertError)
        return jsonResponse(req, { error: 'internal_error' }, 500)
      }
      await insertNotification(admin, {
        userId: userId as string,
        orgId: null,
        type: 'password_reset',
        payload: { email, token },
      })
      await writeAuditLog(admin, {
        eventType: 'patient_password_reset_requested',
        actorUserId: null,
        targetUserId: userId as string,
        orgId: null,
      })
    }

    await padTimingTo(startedAt)
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-request-password-reset error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
