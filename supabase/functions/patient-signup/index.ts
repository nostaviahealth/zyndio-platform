// TC-012 slice 1: patient self-signup. Public (no session). [auth]
// enable_signup stays false (closes GoTrue's own /auth/v1/signup so no
// anonymous caller can create a *staff* account that way) - patients get in
// only through this function, which always creates a plain auth.users row
// with user_metadata.role = 'patient' and NO org_members row (patients are
// never org members; see docs/RECORD_MATCHING.md - org/clinic binding only
// happens later via a second-proof link, out of scope this slice).
//
// Enumeration-safe (PSU-ENUM-01): every outcome that isn't a validation
// error on the caller's own input (bad email shape, weak/blocklisted
// password) returns the identical { status: 'ok' } body, at roughly the
// same wall-clock time (padTimingTo), whether the email is new, already
// registered, or momentarily racing another signup for the same address.
// An email that already exists gets a "someone tried to sign up with your
// email" outbox stub instead of a confirmation mail - never a confirmation
// link for an address the caller doesn't already own.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import {
  generateToken,
  hashTokenHex,
  isPasswordLongEnough,
  isValidEmail,
  normalizeEmail,
} from '../_shared/validation.ts'
import { clientIpFrom, sha256Hex } from '../_shared/clientIp.ts'
import { padTimingTo } from '../_shared/timingPad.ts'

const SIGNUP_IP_LIMIT = 10
const SIGNUP_IP_WINDOW_SECONDS = 15 * 60
const SIGNUP_EMAIL_LIMIT = 5
const SIGNUP_EMAIL_WINDOW_SECONDS = 15 * 60

async function findUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  const { data } = await admin.rpc('find_user_id_by_email', { p_email: email })
  return (data as string | null) ?? null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  const startedAt = Date.now()
  try {
    const admin = serviceRoleClient()
    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const password = body.password

    if (!email || !isValidEmail(email)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }
    if (!isPasswordLongEnough(password)) {
      return jsonResponse(req, { error: 'password_too_short' }, 400)
    }

    const { data: blocked, error: blockedError } = await admin.rpc('password_is_blocked', {
      p_password: password,
    })
    if (blockedError) {
      console.error('patient-signup: password_is_blocked check failed', blockedError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    if (blocked) {
      return jsonResponse(req, { error: 'password_too_common' }, 400)
    }

    const ip = clientIpFrom(req)
    const emailKeyHash = await sha256Hex(email)

    const { data: ipAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_signup_ip',
      p_key_hash: await sha256Hex(ip),
      p_limit: SIGNUP_IP_LIMIT,
      p_window_seconds: SIGNUP_IP_WINDOW_SECONDS,
    })
    const { data: emailAllowed } = await admin.rpc('check_and_consume_rate_limit', {
      p_bucket: 'patient_signup_email',
      p_key_hash: emailKeyHash,
      p_limit: SIGNUP_EMAIL_LIMIT,
      p_window_seconds: SIGNUP_EMAIL_WINDOW_SECONDS,
    })
    if (ipAllowed === false || emailAllowed === false) {
      return jsonResponse(req, { error: 'rate_limited' }, 429)
    }

    const existingUserId = await findUserIdByEmail(admin, email)

    if (existingUserId) {
      await insertNotification(admin, {
        userId: existingUserId,
        orgId: null,
        type: 'signup_attempt_existing_email',
        payload: {},
      })
      await writeAuditLog(admin, {
        eventType: 'patient_signup_attempt_existing_email',
        actorUserId: null,
        targetUserId: existingUserId,
        orgId: null,
      })
      await padTimingTo(startedAt)
      return jsonResponse(req, { status: 'ok' })
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: false,
      user_metadata: { role: 'patient' },
    })

    if (createError || !created?.user) {
      // Lost a race with a concurrent signup for the same email (PSU-DUP-05):
      // looks identical to the "already exists" branch above, never a 500.
      console.error('patient-signup: createUser failed', createError)
      await padTimingTo(startedAt)
      return jsonResponse(req, { status: 'ok' })
    }

    const token = generateToken()
    const tokenHash = await hashTokenHex(token)

    const { error: verificationError } = await admin.from('patient_email_verifications').insert({
      user_id: created.user.id,
      token_hash: tokenHash,
    })
    if (verificationError) {
      console.error('patient-signup: patient_email_verifications insert failed', verificationError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    await insertNotification(admin, {
      userId: created.user.id,
      orgId: null,
      type: 'verify_email',
      payload: { email, token },
    })

    await writeAuditLog(admin, {
      eventType: 'patient_signup',
      actorUserId: created.user.id,
      targetUserId: created.user.id,
      orgId: null,
    })

    await padTimingTo(startedAt)
    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    console.error('patient-signup error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
