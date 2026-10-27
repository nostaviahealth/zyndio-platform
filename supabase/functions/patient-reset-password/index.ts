// TC-012 slice 1: completes a password reset from a 1h-TTL token. Public (no
// session) - the token is the credential, same shape as accept-invite /
// patient-verify-email. Saving signs out every other session
// (revoke-on-password-change, Ava's reset-password/saved copy) via the same
// force_sign_out() used by deactivate-user / reset-mfa.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { hashTokenHex, isPasswordLongEnough } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const token = typeof body.token === 'string' ? body.token : null
    const password = body.password

    if (!token) return jsonResponse(req, { error: 'invalid_or_expired_link' }, 400)
    if (!isPasswordLongEnough(password)) {
      return jsonResponse(req, { error: 'password_too_short' }, 400)
    }

    const { data: blocked, error: blockedError } = await admin.rpc('password_is_blocked', {
      p_password: password,
    })
    if (blockedError) {
      console.error('patient-reset-password: password_is_blocked check failed', blockedError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    if (blocked) {
      return jsonResponse(req, { error: 'password_too_common' }, 400)
    }

    const tokenHash = await hashTokenHex(token)
    const { data: userId, error: redeemError } = await admin.rpc('redeem_patient_password_reset', {
      p_token_hash: tokenHash,
    })
    if (redeemError) {
      console.error('patient-reset-password: redeem failed', redeemError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    if (!userId) {
      return jsonResponse(req, { error: 'invalid_or_expired_link' }, 400)
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(userId as string, {
      password,
    })
    if (updateError) {
      if ((updateError as { code?: string }).code === 'weak_password') {
        return jsonResponse(req, { error: 'password_too_weak' }, 400)
      }
      console.error('patient-reset-password: updateUserById failed', updateError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    const { error: signOutError } = await admin.rpc('force_sign_out', { p_user_id: userId })
    if (signOutError) {
      console.error('patient-reset-password: force_sign_out failed', signOutError)
    }

    await writeAuditLog(admin, {
      eventType: 'patient_password_reset_completed',
      actorUserId: userId as string,
      targetUserId: userId as string,
      orgId: null,
    })

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-reset-password error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
