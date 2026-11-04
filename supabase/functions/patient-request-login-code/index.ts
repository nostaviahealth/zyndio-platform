// APP-01: step 1 of patient sign-in. Public (no session): the patient enters
// the email their care team enrolled them with and we email a 6-digit code.
//
// Enumeration-safe like patient-signup (PSU-ENUM-01): every well-formed
// email gets the same { status: 'ok' } at the same padded time. Only an
// eligible patient account (staff-created / linked, or a self-signup) is
// actually emailed; staff, platform admins and unknown emails get a code row
// that is never sent (issue_patient_login_code), so they also behave the
// same at the verify step.
//
// Throttles: per IP and per email hash (same buckets/limits shape as
// patient-signup). The 5-wrong-tries lock lives with the code itself.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { insertNotification, writeAuditLog } from '../_shared/auditAndNotify.ts'
import { MAX_EMAIL_LENGTH, isValidEmail, normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'
import { LOGIN_CODE_TTL_SECONDS, generateLoginCode } from '../_shared/patientLoginCode.ts'

const REQUEST_IP_LIMIT = 10
const REQUEST_IP_WINDOW_SECONDS = 15 * 60
const REQUEST_EMAIL_LIMIT = 5
const REQUEST_EMAIL_WINDOW_SECONDS = 15 * 60
const PAD_MS = 400

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    if (!email || email.length > MAX_EMAIL_LENGTH || !isValidEmail(email)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const ipKey = await sha256Hex(clientIpFrom(req))
    const { data: ipAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_login_code_request_ip',
      p_key_hash: ipKey,
      p_limit: REQUEST_IP_LIMIT,
      p_window_seconds: REQUEST_IP_WINDOW_SECONDS,
    })
    const { data: emailAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_login_code_request_email',
      p_key_hash: await sha256Hex(email),
      p_limit: REQUEST_EMAIL_LIMIT,
      p_window_seconds: REQUEST_EMAIL_WINDOW_SECONDS,
    })
    if (ipAllowed === false || emailAllowed === false) {
      await padTimingTo(startedAt, PAD_MS)
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const code = generateLoginCode()
    const { data: userId, error: issueError } = await admin.rpc('issue_patient_login_code', {
      p_email: email,
      p_code: code,
      p_ttl_seconds: LOGIN_CODE_TTL_SECONDS,
    })
    if (issueError) {
      // Never log the code or the email.
      console.error('patient-request-login-code: issue failed', { code: issueError.code })
      await padTimingTo(startedAt, PAD_MS)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    if (typeof userId === 'string' && userId.length > 0) {
      await insertNotification(admin, {
        userId,
        orgId: null,
        type: 'patient_login_code',
        payload: { email, token: code, expires_in_minutes: LOGIN_CODE_TTL_SECONDS / 60 },
      })
      await writeAuditLog(admin, {
        eventType: 'patient_login_code_sent',
        actorUserId: null,
        targetUserId: userId,
        orgId: null,
        metadata: { ip_hash: ipKey.slice(0, 12) },
      })
    }

    await padTimingTo(startedAt, PAD_MS)
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-request-login-code error', err)
    await padTimingTo(startedAt, PAD_MS)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
