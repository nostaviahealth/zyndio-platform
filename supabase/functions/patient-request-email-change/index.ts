// TC-012 PSU-EV-05: request email change. Old email remains login identity
// until confirm. Enumeration-safe for the *new* address availability is not
// required the same way (caller is authenticated); still avoid leaking
// whether new_email is already taken beyond a generic error after confirm.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import {
  generateToken,
  hashTokenHex,
  isValidEmail,
  normalizeEmail,
} from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'

const CHANGE_TTL_HOURS = 24
const IP_LIMIT = 10
const IP_WINDOW = 15 * 60

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

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

    const body = await req.json().catch(() => ({}))
    const newEmail = normalizeEmail(body.new_email)
    if (!newEmail || !isValidEmail(newEmail)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }
    if (newEmail === normalizeEmail(user.email ?? '')) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const admin = serviceRoleClient()
    const ipKey = await sha256Hex(clientIpFrom(req))
    const { data: ipAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_email_change_ip',
      p_key_hash: ipKey,
      p_limit: IP_LIMIT,
      p_window_seconds: IP_WINDOW,
    })
    if (ipAllowed === false) {
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const token = generateToken()
    const tokenHash = await hashTokenHex(token)
    const expiresAt = new Date(Date.now() + CHANGE_TTL_HOURS * 3600 * 1000).toISOString()

    // Invalidate prior outstanding requests for this user.
    await admin
      .from('patient_email_change_requests')
      .update({ used_at: new Date().toISOString() })
      .eq('user_id', user.id)
      .is('used_at', null)

    const { error: insertError } = await admin.from('patient_email_change_requests').insert({
      user_id: user.id,
      new_email: newEmail,
      token_hash: tokenHash,
      expires_at: expiresAt,
    })
    if (insertError) {
      console.error('patient-request-email-change insert', insertError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    await insertNotification(admin, {
      userId: user.id,
      orgId: null,
      type: 'patient_email_change',
      payload: { token }, // stub outbox; real mailer redacts in transit logs
    })
    await writeAuditLog(admin, {
      eventType: 'patient_email_change_requested',
      actorUserId: user.id,
      targetUserId: user.id,
      orgId: null,
      metadata: {},
    })

    // Old email remains authoritative — do not mutate auth.users.email here.
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-request-email-change', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
