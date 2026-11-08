// TC-012 slice 1: in-app account deletion (Apple 5.1.1(v)). Authenticated,
// aal1 is fine (patients never enroll MFA in this card) - requireAuthenticatedActor
// resolves the caller from their own bearer token, never from a client-
// asserted user id. Re-auth with the CURRENT password is required before any
// write (Ava's reauth screen) via a throwaway anon sign-in that never
// persists a session. Clinic records are never touched - docs/RECORD_MATCHING.md
// and Ava's copy both say clinic data stays with the clinic; this slice has
// no linking yet, so there is nothing clinic-side to leave behind anyway.
//
// APP-01: invited patients sign in with an emailed code and never set a
// password, so the re-auth can also be a FRESH sign-in code for the
// caller's own email (requested via patient-request-login-code). It is
// redeemed through the same redeem_patient_login_code() as sign-in - same
// expiry, single use and 5-try lock - and must belong to the caller.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireAuthenticatedActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import {
  LOGIN_CODE_LOCK_SECONDS,
  LOGIN_CODE_MAX_ATTEMPTS,
  isLoginCode,
  parseRedeemResult,
} from '../_shared/patientLoginCode.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const { userId, admin } = await requireAuthenticatedActor(req)

    const body = await req.json().catch(() => ({}))
    const password = body.password
    const code = typeof body.code === 'string' ? body.code.trim() : null
    const hasPassword = typeof password === 'string' && password.length > 0
    if (!hasPassword && !isLoginCode(code)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const { data: userData, error: getUserError } = await admin.auth.admin.getUserById(userId)
    if (getUserError || !userData?.user?.email) {
      console.error('patient-delete-account: getUserById failed', getUserError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    if (hasPassword) {
      // Throwaway client: persistSession/autoRefreshToken false so this
      // never touches the caller's real session or local storage - it only
      // proves the caller still knows the current password (reauth gate).
      const reauthClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { auth: { autoRefreshToken: false, persistSession: false } },
      )
      const { error: reauthError } = await reauthClient.auth.signInWithPassword({
        email: userData.user.email,
        password,
      })
      if (reauthError) {
        return jsonResponse(req, { error: 'reauth_failed' }, 401)
      }
    } else {
      const { data: redeemData, error: redeemError } = await admin.rpc('redeem_patient_login_code', {
        p_email: userData.user.email,
        p_code: code,
        p_max_attempts: LOGIN_CODE_MAX_ATTEMPTS,
        p_lock_seconds: LOGIN_CODE_LOCK_SECONDS,
      })
      if (redeemError) {
        console.error('patient-delete-account: redeem failed', { code: redeemError.code })
        return jsonResponse(req, { error: 'internal_error' }, 500)
      }
      const outcome = parseRedeemResult(redeemData)
      if (outcome.result === 'locked') {
        return jsonResponse(req, { error: 'locked', retry_after_seconds: outcome.retryAfterSeconds }, 429)
      }
      if (outcome.result !== 'ok' || outcome.userId !== userId) {
        return jsonResponse(req, { error: 'reauth_failed' }, 401)
      }
    }

    await writeAuditLog(admin, {
      eventType: 'patient_account_deletion_requested',
      actorUserId: userId,
      targetUserId: userId,
      orgId: null,
    })

    const { error: appDataError } = await admin.rpc('delete_patient_app_data', {
      p_user_id: userId,
    })
    if (appDataError) {
      console.error('patient-delete-account: delete_patient_app_data failed', appDataError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    // Stub confirmation email before the auth.users row disappears -
    // no PHI in the payload, nothing here depends on the row still existing.
    await insertNotification(admin, {
      userId,
      orgId: null,
      type: 'account_deletion_confirmation',
      payload: {},
    })

    const { error: signOutError } = await admin.rpc('force_sign_out', { p_user_id: userId })
    if (signOutError) {
      console.error('patient-delete-account: force_sign_out failed', signOutError)
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId)
    if (deleteError) {
      console.error('patient-delete-account: deleteUser failed', deleteError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'patient_account_deleted',
      actorUserId: null,
      targetUserId: userId,
      orgId: null,
    })

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('patient-delete-account error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
