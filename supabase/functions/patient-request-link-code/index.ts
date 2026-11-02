// TC-012: request telehealth link OTP. Authenticated + email-confirmed.
// PSU-TO-14: identical success body for 0 / 1 / many matches (timing padded).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { normalizeEmail } from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'
import { createTelehealthConnector } from '../_shared/telehealthConnector.ts'

const USER_LIMIT = 3
const USER_WINDOW = 15 * 60
const IP_LIMIT = 10
const IP_WINDOW = 15 * 60
// L19: no silent default org UUID. Prefer connector match orgId; else require env.
function requireOrgId(fromConnector: string | undefined): string {
  const fromEnv = Deno.env.get('ZYNDIO_DEFAULT_ORG_ID')?.trim()
  const orgId = (fromConnector?.trim() || fromEnv) || ''
  if (!orgId) {
    throw new Error(
      'ZYNDIO_DEFAULT_ORG_ID is not set and connector match did not supply orgId',
    )
  }
  return orgId
}

function sixDigitCode(): string {
  const buf = new Uint32Array(1)
  crypto.getRandomValues(buf)
  return String(buf[0] % 1_000_000).padStart(6, '0')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  const okBody = {
    status: 'ok',
    message:
      "If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages.",
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) {
      return jsonResponse(req, { error: 'unauthorized' }, 401)
    }
    const anon = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: userData, error: userError } = await anon.auth.getUser()
    if (userError || !userData.user) {
      return jsonResponse(req, { error: 'unauthorized' }, 401)
    }
    const user = userData.user
    if (!user.email_confirmed_at) {
      return jsonResponse(req, { error: 'email_unconfirmed' }, 403)
    }

    const admin = serviceRoleClient()
    const ipKey = await sha256Hex(clientIpFrom(req))
    const userKey = await sha256Hex(user.id)

    const { data: userAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_link_otp_user',
      p_key_hash: userKey,
      p_limit: USER_LIMIT,
      p_window_seconds: USER_WINDOW,
    })
    const { data: ipAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_link_otp_ip',
      p_key_hash: ipKey,
      p_limit: IP_LIMIT,
      p_window_seconds: IP_WINDOW,
    })
    if (userAllowed === false || ipAllowed === false) {
      await padTimingTo(startedAt, 400)
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const connector = createTelehealthConnector()
    // TC-021 #9 deno check (TS2322): normalizeEmail returns string | null.
    const email = normalizeEmail(user.email ?? '') ?? ''
    const locate = await connector.locateForCodeRequest({
      appUserId: user.id,
      normalisedEmail: email,
    })

    if (locate.kind === 'one') {
      const orgId = requireOrgId(locate.orgId)
      const code = sixDigitCode()
      const { error: issueError } = await admin.rpc('issue_telehealth_link_otp', {
        p_app_user_id: user.id,
        p_telehealth_patient_id: locate.telehealthPatientId,
        p_org_id: orgId,
        p_plain_code: code,
        p_ttl_minutes: 10,
      })
      if (issueError) {
        // Never log the plain code (Clara M13).
        console.error('patient-request-link-code: issue failed', {
          message: issueError.message,
          code: issueError.code,
        })
      } else {
        // SQL issue RPC also writes telehealth_message_outbox with the code.
        // Mirror into the in-process adapter outbox for Deno unit visibility —
        // body must carry the redeemable code (never log it).
        await connector.sendPatientMessage({
          telehealthPatientId: locate.telehealthPatientId,
          body:
            `Your Zyndio link code is ${code}. It expires in 10 minutes and works once. Not you? Ignore this message.`,
        })
      }
    } else if (locate.kind === 'ambiguous') {
      const orgId = requireOrgId(undefined)
      await admin.rpc('enqueue_patient_link_review', {
        p_app_user_id: user.id,
        p_org_id: orgId,
        p_reason: 'ambiguous_match',
        p_payload: { note: 'opaque' },
      })
    } else {
      await writeAuditLog(admin, {
        eventType: 'patient_link_otp_no_match',
        actorUserId: user.id,
        targetUserId: user.id,
        orgId: null,
        metadata: {},
      })
    }

    await padTimingTo(startedAt, 400)
    return jsonResponse(req, okBody, 200)
  } catch (err) {
    console.error('patient-request-link-code', err)
    await padTimingTo(startedAt, 400)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
