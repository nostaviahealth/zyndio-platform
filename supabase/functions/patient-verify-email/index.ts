// TC-012 slice 1: consumes the 24h email-verification token issued by
// patient-signup / patient-resend-verification. Public (no session) - the
// token itself is the credential, same pattern as accept-invite. The token
// is unguessable (32 random bytes) so, unlike signup/login/reset, there is
// no enumeration concern here to pad against: a wrong/expired/reused token
// gets one generic error (PSU-EV-02 expiry, PSU-EV-03 reuse, PSU-EV-04
// forged-token resistance all land on the same branch).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { hashTokenHex } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const body = await req.json().catch(() => ({}))
    const token = typeof body.token === 'string' ? body.token : null
    if (!token) return jsonResponse(req, { error: 'invalid_or_expired_link' }, 400)

    const admin = serviceRoleClient()
    const tokenHash = await hashTokenHex(token)

    const { data: userId, error: redeemError } = await admin.rpc(
      'redeem_patient_email_verification',
      { p_token_hash: tokenHash },
    )
    if (redeemError) {
      console.error('patient-verify-email: redeem failed', redeemError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    if (!userId) {
      return jsonResponse(req, { error: 'invalid_or_expired_link' }, 400)
    }

    const { error: confirmError } = await admin.auth.admin.updateUserById(userId as string, {
      email_confirm: true,
    })
    if (confirmError) {
      console.error('patient-verify-email: updateUserById failed', confirmError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'patient_email_verified',
      actorUserId: userId as string,
      targetUserId: userId as string,
      orgId: null,
    })

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-verify-email error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
