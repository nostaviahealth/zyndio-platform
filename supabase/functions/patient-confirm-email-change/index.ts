// TC-012 PSU-EV-05: confirm email change with single-use token. Until this
// succeeds, login + link codes stay on the old address.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { hashTokenHex } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const body = await req.json().catch(() => ({}))
    const token = typeof body.token === 'string' ? body.token : ''
    if (!token) return jsonResponse(req, { error: 'invalid_or_expired_link' }, 400)

    const admin = serviceRoleClient()
    const tokenHash = await hashTokenHex(token)
    const { data, error } = await admin.rpc('redeem_patient_email_change', {
      p_token_hash: tokenHash,
    })
    if (error) {
      console.error('redeem_patient_email_change', error)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    const result = data as { ok?: boolean; error?: string; user_id?: string }
    if (!result?.ok) {
      return jsonResponse(req, { error: result?.error ?? 'invalid_or_expired_link' }, 400)
    }

    if (result.user_id) {
      await admin.rpc('force_sign_out', { p_user_id: result.user_id })
    }
    await writeAuditLog(admin, {
      eventType: 'patient_email_change_confirmed',
      actorUserId: result.user_id ?? null,
      targetUserId: result.user_id ?? null,
      orgId: null,
      metadata: {},
    })
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-confirm-email-change', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
