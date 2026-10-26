// Public (no admin session) - the invite token itself is the credential.
// One generic error for every "this token doesn't work" case (expired,
// revoked, already used, or simply wrong) so a guesser can't learn which.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { hashTokenHex, isPasswordLongEnough } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json().catch(() => ({}))
    const token = typeof body.token === 'string' ? body.token : null
    const password = body.password

    if (!token) return jsonResponse({ error: 'invalid_or_expired_invite' }, 400)

    const admin = serviceRoleClient()
    const tokenHash = await hashTokenHex(token)

    const { data: invite } = await admin
      .from('invites')
      .select('id, org_id, user_id, expires_at, accepted_at, revoked_at')
      .eq('token_hash', tokenHash)
      .maybeSingle()

    const isLive =
      !!invite &&
      !invite.accepted_at &&
      !invite.revoked_at &&
      new Date(invite.expires_at).getTime() > Date.now()

    if (!isLive) {
      return jsonResponse({ error: 'invalid_or_expired_invite' }, 400)
    }

    if (!isPasswordLongEnough(password)) {
      return jsonResponse({ error: 'password_too_short' }, 400)
    }

    const { data: blocked, error: blockedError } = await admin.rpc('password_is_blocked', {
      p_password: password,
    })
    if (blockedError) {
      console.error('accept-invite: password_is_blocked check failed', blockedError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }
    if (blocked) {
      return jsonResponse({ error: 'password_too_common' }, 400)
    }

    const { error: updateUserError } = await admin.auth.admin.updateUserById(invite!.user_id, {
      password,
      email_confirm: true,
    })
    if (updateUserError) {
      console.error('accept-invite: updateUserById failed', updateUserError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    // Only activate if the member is still 'invited' - if an admin
    // deactivated them while the invite was still live, this must not
    // silently reverse that (H3). select() + .length lets us see how many
    // rows actually matched, since an .eq('status','invited') that matches
    // zero rows otherwise looks identical to success.
    const { data: activated, error: memberError } = await admin
      .from('org_members')
      .update({ status: 'active' })
      .eq('user_id', invite!.user_id)
      .eq('org_id', invite!.org_id)
      .eq('status', 'invited')
      .select('user_id')
    if (memberError) {
      console.error('accept-invite: org_members update failed', memberError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }
    if (!activated || activated.length === 0) {
      return jsonResponse({ error: 'invalid_or_expired_invite' }, 400)
    }

    const { error: inviteUpdateError } = await admin
      .from('invites')
      .update({ accepted_at: new Date().toISOString() })
      .eq('id', invite!.id)
    if (inviteUpdateError) {
      console.error('accept-invite: invites update failed', inviteUpdateError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'invite_accepted',
      actorUserId: invite!.user_id,
      targetUserId: invite!.user_id,
      orgId: invite!.org_id,
    })

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    console.error('accept-invite error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
