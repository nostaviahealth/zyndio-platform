// Org-admin-only. Reverses deactivate-user; no forced sign-out needed since
// a deactivated member has no valid session to speak of.
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

    if (target.status !== 'deactivated') {
      return jsonResponse({ error: 'not_deactivated' }, 409)
    }

    const { error: updateError } = await admin
      .from('org_members')
      .update({ status: 'active' })
      .eq('user_id', targetUserId)
      .eq('org_id', actor.orgId)

    if (updateError) {
      console.error('reactivate-user: org_members update failed', updateError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    await writeAuditLog(admin, {
      eventType: 'user_reactivated',
      actorUserId: actor.userId,
      targetUserId,
      orgId: actor.orgId,
    })

    await insertNotification(admin, {
      userId: targetUserId,
      orgId: actor.orgId,
      type: 'user_reactivated',
    })

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('reactivate-user error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
