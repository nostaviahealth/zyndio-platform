// TC-012: patient email/password login with per-IP failure throttle (PSU-RL-03).
// GoTrue has no per-IP login limiter; this Edge Function fronts password grant
// so credential stuffing across many emails from one IP hits rate_limit_counters
// before GoTrue. Per-account lockout remains the TC-005 password hook.
// Enumeration-safe: failure returns the same generic invalid_credentials shape.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { isValidEmail, normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'

/** Failures per IP per window before 429 (PSU-RL-03). Config-driven later. */
const LOGIN_IP_FAIL_LIMIT = 30
const LOGIN_IP_WINDOW_SECONDS = 15 * 60

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const password = typeof body.password === 'string' ? body.password : ''

    if (!email || !isValidEmail(email) || !password) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const ip = clientIpFrom(req)
    const ipKey = await sha256Hex(ip)

    const { data: ipAllowed } = await admin.rpc('peek_rate_limit', {
      p_bucket: 'patient_login_ip',
      p_key_hash: ipKey,
      p_limit: LOGIN_IP_FAIL_LIMIT,
      p_window_seconds: LOGIN_IP_WINDOW_SECONDS,
    })
    if (ipAllowed === false) {
      await writeAuditLog(admin, {
        eventType: 'patient_login_ip_rate_limited',
        actorUserId: null,
        targetUserId: null,
        orgId: null,
        metadata: { ip_hash: ipKey.slice(0, 12) },
      })
      await padTimingTo(startedAt, 250)
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const tokenRes = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: anonKey,
        Authorization: `Bearer ${anonKey}`,
      },
      body: JSON.stringify({ email, password }),
    })
    const tokenJson = await tokenRes.json().catch(() => ({}))

    if (!tokenRes.ok || !tokenJson.access_token) {
      await admin.rpc('check_and_consume_rate_limit', {
        p_bucket: 'patient_login_ip',
        p_key_hash: ipKey,
        p_limit: LOGIN_IP_FAIL_LIMIT,
        p_window_seconds: LOGIN_IP_WINDOW_SECONDS,
      })
      await writeAuditLog(admin, {
        eventType: 'patient_login_failed',
        actorUserId: null,
        targetUserId: null,
        orgId: null,
        metadata: { ip_hash: ipKey.slice(0, 12) },
      })
      await padTimingTo(startedAt, 250)
      return jsonResponse(req, { error: 'invalid_credentials' }, 401)
    }

    await writeAuditLog(admin, {
      eventType: 'patient_login_ok',
      actorUserId: tokenJson.user?.id ?? null,
      targetUserId: tokenJson.user?.id ?? null,
      orgId: null,
      metadata: {},
    })
    if (tokenJson.user?.id) {
      const { error: meterError } = await admin.rpc('record_patient_monthly_activity', {
        p_patient_id: tokenJson.user.id,
        p_reason: 'sign_in',
      })
      if (meterError) console.error('meter_sign_in_failed', meterError.message)
    }
    await padTimingTo(startedAt, 250)
    return jsonResponse(req, {
      status: 'ok',
      access_token: tokenJson.access_token,
      refresh_token: tokenJson.refresh_token,
      expires_in: tokenJson.expires_in,
      token_type: tokenJson.token_type ?? 'bearer',
      user: { id: tokenJson.user?.id, email: tokenJson.user?.email },
    })
  } catch (err) {
    console.error('patient-login error', err)
    await padTimingTo(startedAt, 250)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
