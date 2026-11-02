// Org-admin-only: creates the invited person's auth.users row and an
// 'invited' org_members row up front (so accept-invite never has to resolve
// an email back to a user id), plus a single-use 7-day invite token. Never
// reveals whether the email already has an account anywhere else - every
// outcome that isn't a validation error on the *caller's own input* returns
// the identical `{ status: 'ok' }` body.
//
// TC-014 / Clara M16: Full name is required; role must be one the inviter
// can grant (canGrantRole / public.can_grant_role). Role and full_name are
// stored on invites and org_members at invite time (server-owned name —
// not user_metadata) and applied at accept - never trusted from the client
// then.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireOrgAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import {
  canGrantRole,
  generatePlaceholderPassword,
  generateToken,
  hashTokenHex,
  isValidAppRole,
  isValidEmail,
  normalizeEmail,
  normalizeFullName,
} from '../_shared/validation.ts'
import { isCancelledInviteLeftover } from '../_shared/cancelInviteAuthDelete.ts'

async function findUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  const { data } = await admin.rpc('find_user_id_by_email', { p_email: email })
  return (data as string | null) ?? null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const { actor, admin } = await requireOrgAdminActor(req)

    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const role = body.role
    const fullName = normalizeFullName(body.full_name ?? body.fullName)

    if (!fullName) {
      return jsonResponse(req, { error: 'invalid_request', field: 'full_name' }, 400)
    }
    if (!email || !isValidEmail(email)) {
      return jsonResponse(req, { error: 'invalid_request', field: 'email' }, 400)
    }
    if (!isValidAppRole(role)) {
      return jsonResponse(req, { error: 'invalid_request', field: 'role' }, 400)
    }
    if (!canGrantRole(actor.role, role)) {
      return jsonResponse(req, { error: 'role_not_allowed' }, 403)
    }

    let userId: string
    // Tracks whether this call itself just created the auth.users row (with
    // a random, nobody-knows-it placeholder password) versus the email
    // already having an account before this invite (M6: a patient account,
    // the bootstrap admin, or anything else outside the invite flow). Only
    // the former may ever be attached to org_members / have its password
    // overwritten by accept-invite.
    let isFreshAuthUser: boolean
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password: generatePlaceholderPassword(),
      email_confirm: true,
    })

    if (createError || !created?.user) {
      const existingId = await findUserIdByEmail(admin, email)
      if (!existingId) {
        // The email belongs to an auth.users row we have no record of
        // (e.g. provisioned outside the invite flow, such as the bootstrap
        // admin). Never reveal that via an error - respond exactly like a
        // successful invite and do nothing further.
        return jsonResponse(req, { status: 'ok' })
      }
      userId = existingId
      isFreshAuthUser = false
    } else {
      userId = created.user.id
      isFreshAuthUser = true
    }

    const { data: existingMember } = await admin
      .from('org_members')
      .select('org_id, status')
      .eq('user_id', userId)
      .maybeSingle()

    if (existingMember && existingMember.org_id === actor.orgId && existingMember.status === 'invited') {
      // Resend: supersede any still-live invite for this org/email before
      // issuing a fresh token (the partial unique index only allows one
      // live invite per org+email at a time). Also pick up a changed role
      // (L7) and name (TC-014).
      await admin
        .from('invites')
        .update({ revoked_at: new Date().toISOString() })
        .eq('org_id', actor.orgId)
        .ilike('email', email)
        .is('accepted_at', null)
        .is('revoked_at', null)
      const { error: roleUpdateError } = await admin
        .from('org_members')
        .update({ role, full_name: fullName })
        .eq('user_id', userId)
        .eq('org_id', actor.orgId)
      if (roleUpdateError) {
        console.error('invite-user: org_members role/name update on resend failed', roleUpdateError)
        return jsonResponse(req, { error: 'internal_error' }, 500)
      }
    } else if (existingMember) {
      // Already active/deactivated in this org, or belongs to a different
      // org entirely - nothing to do, but looks identical to success.
      return jsonResponse(req, { status: 'ok' })
    } else if (!isFreshAuthUser) {
      // M6: an account that existed before this invite call (a patient
      // account, or anything else never routed through invite-user) and
      // has no org_members row at all. Never silently attach org/staff
      // access to it — unless Clara L30: it is only a leftover from a
      // cancelled invite whose auth delete failed (no patient / platform
      // admin / self-signup, only revoked invite history).
      const leftover = await isCancelledInviteLeftover(admin, userId)
      if (!leftover) {
        return jsonResponse(req, { status: 'ok' })
      }
      const { error: memberError } = await admin.from('org_members').insert({
        user_id: userId,
        org_id: actor.orgId,
        role,
        status: 'invited',
        full_name: fullName,
      })
      if (memberError) {
        console.error('invite-user: org_members insert on leftover re-invite failed', memberError)
        return jsonResponse(req, { error: 'internal_error' }, 500)
      }
    } else {
      const { error: memberError } = await admin.from('org_members').insert({
        user_id: userId,
        org_id: actor.orgId,
        role,
        status: 'invited',
        full_name: fullName,
      })
      if (memberError) {
        console.error('invite-user: org_members insert failed', memberError)
        return jsonResponse(req, { error: 'internal_error' }, 500)
      }
    }

    const token = generateToken()
    const tokenHash = await hashTokenHex(token)

    const { error: inviteError } = await admin.from('invites').insert({
      org_id: actor.orgId,
      email,
      role,
      full_name: fullName,
      token_hash: tokenHash,
      invited_by: actor.userId,
      user_id: userId,
    })
    if (inviteError) {
      console.error('invite-user: invites insert failed', inviteError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'invite_sent',
      actorUserId: actor.userId,
      targetUserId: userId,
      orgId: actor.orgId,
      metadata: { email, role, full_name: fullName },
    })

    await insertNotification(admin, {
      userId,
      orgId: actor.orgId,
      type: 'invite',
      payload: { email, token },
    })

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('invite-user error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
