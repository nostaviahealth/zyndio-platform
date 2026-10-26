// Org-admin-only. public.enforce_last_admin (schema migration trigger)
// rejects deactivating the last active org_admin - surfaced here as a
// specific, non-enumeration-sensitive error since the caller is already an
// authenticated admin of this org.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireOrgAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog, insertNotification } from '../_shared/auditAndNotify.ts'
import { isValidUuid } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { actor, admin } = await requireOrgAdminActor(req)

    const body = await req.json().catch(() => ({}))
    const targetUserId = body.target_user_id

    if (!isValidUuid(targetUserId)) {
      return jsonResponse({ error: 'invalid_request' }, 400)
    }

    const { data: target } = await admin
      .from('org_members')
      .select('org_id, status')
      .eq('user_id', targetUserId)
      .maybeSingle()

    if (!target || target.org_id !== actor.orgId) {
      return jsonResponse({ error: 'not_found' }, 404)
    }

    const { error: updateError } = await admin
      .from('org_members')
      .update({ status: 'deactivated' })
      .eq('user_id', targetUserId)
      .eq('org_id', actor.orgId)

    if (updateError) {
      if (updateError.code === 'P0001') {
        return jsonResponse({ error: 'cannot_deactivate_last_admin' }, 409)
      }
      console.error('deactivate-user: org_members update failed', updateError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    // A deactivated member must not be able to reactivate themselves by
    // walking in on a still-live invite link (H3) - revoke every pending
    // invite for them in this org.
    const { error: revokeInvitesError } = await admin
      .from('invites')
      .update({ revoked_at: new Date().toISOString() })
      .eq('org_id', actor.orgId)
      .eq('user_id', targetUserId)
      .is('accepted_at', null)
      .is('revoked_at', null)
    if (revokeInvitesError) {
      console.error('deactivate-user: revoking pending invites failed', revokeInvitesError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    const { error: signOutError } = await admin.rpc('force_sign_out', { p_user_id: targetUserId })
    if (signOutError) {
      console.error('deactivate-user: force_sign_out failed', signOutError)
    }

    await writeAuditLog(admin, {
      eventType: 'user_deactivated',
      actorUserId: actor.userId,
      targetUserId,
      orgId: actor.orgId,
    })

    await insertNotification(admin, {
      userId: targetUserId,
      orgId: actor.orgId,
      type: 'user_deactivated',
    })

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('deactivate-user error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
