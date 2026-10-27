// Org-admin-only: creates the invited person's auth.users row and an
// 'invited' org_members row up front (so accept-invite never has to resolve
// an email back to a user id), plus a single-use 7-day invite token. Never
// reveals whether the email already has an account anywhere else - every
// outcome that isn't a validation error on the *caller's own input* returns
// the identical `{ status: 'ok' }` body.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireOrgAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import {
  generatePlaceholderPassword,
  generateToken,
  hashTokenHex,
  isValidAppRole,
  isValidEmail,
  normalizeEmail,
} from '../_shared/validation.ts'

// Resolves an email that already has an auth.users row (createUser just
// failed with "already registered") back to its user id - via the
// find_user_id_by_email() SQL function, not GoTrue's admin listUsers
// endpoint. listUsers() scans every user in the instance and is one bad row
// away from a hard failure (observed live: a NULL confirmation_token on an
// unrelated account 500s the whole list, which would otherwise turn a
// routine re-invite into an error - and a 500-vs-200 split is itself an
// enumeration side channel).
async function findUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | null> {
  const { data } = await admin.rpc('find_user_id_by_email', { p_email: email })
  return (data as string | null) ?? null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { actor, admin } = await requireOrgAdminActor(req)

    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const role = body.role

    if (!email || !isValidEmail(email) || !isValidAppRole(role)) {
      return jsonResponse({ error: 'invalid_request' }, 400)
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
        return jsonResponse({ status: 'ok' })
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
      // (L7): a resend with a different role must not keep the stale one.
      await admin
        .from('invites')
        .update({ revoked_at: new Date().toISOString() })
        .eq('org_id', actor.orgId)
        .ilike('email', email)
        .is('accepted_at', null)
        .is('revoked_at', null)
      // TC-011: role changes on re-invite stay inside the inviter's org only.
      const { error: roleUpdateError } = await admin
        .from('org_members')
        .update({ role })
        .eq('user_id', userId)
        .eq('org_id', actor.orgId)
      if (roleUpdateError) {
        console.error('invite-user: org_members role update on resend failed', roleUpdateError)
        return jsonResponse({ error: 'internal_error' }, 500)
      }
    } else if (existingMember) {
      // Already active/deactivated in this org, or belongs to a different
      // org entirely - nothing to do, but looks identical to success.
      return jsonResponse({ status: 'ok' })
    } else if (!isFreshAuthUser) {
      // M6: an account that existed before this invite call (a patient
      // account, or anything else never routed through invite-user) and
      // has no org_members row at all. Never silently attach org/staff
      // access to it, and never let accept-invite later overwrite its real
      // password - refuse, but look identical to a successful invite.
      return jsonResponse({ status: 'ok' })
    } else {
      const { error: memberError } = await admin.from('org_members').insert({
        user_id: userId,
        org_id: actor.orgId,
        role,
        status: 'invited',
      })
      if (memberError) {
        console.error('invite-user: org_members insert failed', memberError)
        return jsonResponse({ error: 'internal_error' }, 500)
      }
    }

    const token = generateToken()
    const tokenHash = await hashTokenHex(token)

    const { error: inviteError } = await admin.from('invites').insert({
      org_id: actor.orgId,
      email,
      role,
      token_hash: tokenHash,
      invited_by: actor.userId,
      user_id: userId,
    })
    if (inviteError) {
      console.error('invite-user: invites insert failed', inviteError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'invite_sent',
      actorUserId: actor.userId,
      targetUserId: userId,
      orgId: actor.orgId,
      metadata: { email, role },
    })

    // B5: stays 'pending' with the plaintext token until process-outbox (the
    // stub email worker) "sends" it - see supabase/functions/process-outbox.
    // Modeled as an async worker rather than inline here because a real
    // provider (TC-006) would be async too, and because the plaintext token
    // genuinely needs to survive until *something* delivers it; nulling it
    // at insert time would make the invite link unrecoverable by anyone.
    await insertNotification(admin, {
      userId,
      orgId: actor.orgId,
      type: 'invite',
      payload: { email, token },
    })

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('invite-user error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
