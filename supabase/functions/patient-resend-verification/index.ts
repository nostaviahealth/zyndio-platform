// TC-012 slice 1: resend the sign-up verification email. Public (no
// session). PSU-ENUM-04: identical { status: 'ok' } whether the email is
// unknown, already verified, or a real unverified patient - the only
// visible difference is the UI's own 60s client-side cooldown timer, never a
// server-side "you have to wait" error. Server-side the cooldown and the
// 5/15min cap are both enforced silently (a call inside either window is a
// no-op that still returns 'ok').
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import { generateToken, hashTokenHex, isValidEmail, normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'

const RESEND_COOLDOWN_SECONDS = 60
const RESEND_EMAIL_LIMIT = 5
const RESEND_EMAIL_WINDOW_SECONDS = 15 * 60

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
      p_bucket: 'patient_resend_ip',
      p_key_hash: await sha256Hex(ip),
      p_limit: 10,
      p_window_seconds: RESEND_EMAIL_WINDOW_SECONDS,
    })
    const { data: emailAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_resend_email',
      p_key_hash: await sha256Hex(email),
      p_limit: RESEND_EMAIL_LIMIT,
      p_window_seconds: RESEND_EMAIL_WINDOW_SECONDS,
    })
    if (ipAllowed === false || emailAllowed === false) {
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const { data: userId } = await admin.rpc('find_user_id_by_email', { p_email: email })

    if (userId) {
      const { data: userData } = await admin.auth.admin.getUserById(userId as string)
      const alreadyVerified = !!userData?.user?.email_confirmed_at

      if (!alreadyVerified) {
        const { data: lastVerification } = await admin
          .from('patient_email_verifications')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle()

        const withinCooldown =
          !!lastVerification &&
          Date.now() - new Date(lastVerification.created_at as string).getTime() <
            RESEND_COOLDOWN_SECONDS * 1000

        if (!withinCooldown) {
          const token = generateToken()
          const tokenHash = await hashTokenHex(token)
          await admin
            .from('patient_email_verifications')
            .insert({ user_id: userId, token_hash: tokenHash })
          await insertNotification(admin, {
            userId: userId as string,
            orgId: null,
            type: 'verify_email',
            payload: { email, token },
          })
          await writeAuditLog(admin, {
            eventType: 'patient_verification_resent',
            actorUserId: null,
            targetUserId: userId as string,
            orgId: null,
          })
        }
      }
    }

    await padTimingTo(startedAt)
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-resend-verification error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
