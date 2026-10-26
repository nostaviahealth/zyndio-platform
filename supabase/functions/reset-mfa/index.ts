// Org-admin-only. Never the caller's own row (server-enforced, not just a
// hidden UI button). Removes the target's TOTP factor(s), flags them for
// mandatory re-enrollment, forces a global sign-out, and audits + notifies.
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

    if (targetUserId === actor.userId) {
      return jsonResponse({ error: 'cannot_reset_own_mfa' }, 403)
    }

    const { data: target } = await admin
      .from('org_members')
      .select('org_id, status')
      .eq('user_id', targetUserId)
      .maybeSingle()

    if (!target || target.org_id !== actor.orgId) {
      return jsonResponse({ error: 'not_found' }, 404)
    }

    const { data: factorData, error: factorListError } = await admin.auth.admin.mfa.listFactors({
      userId: targetUserId,
    })
    if (factorListError) {
      console.error('reset-mfa: listFactors failed', factorListError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    for (const factor of factorData?.factors ?? []) {
      const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({
        userId: targetUserId,
        id: factor.id,
      })
      if (deleteError) {
        console.error('reset-mfa: deleteFactor failed', deleteError)
        return jsonResponse({ error: 'internal_error' }, 500)
      }
    }

    await admin.from('mfa_reenrollment_required').upsert({ user_id: targetUserId })

    const { error: signOutError } = await admin.rpc('force_sign_out', { p_user_id: targetUserId })
    if (signOutError) {
      console.error('reset-mfa: force_sign_out failed', signOutError)
    }

    await writeAuditLog(admin, {
      eventType: 'mfa_reset',
      actorUserId: actor.userId,
      targetUserId,
      orgId: actor.orgId,
    })

    await insertNotification(admin, {
      userId: targetUserId,
      orgId: actor.orgId,
      type: 'mfa_reset',
    })

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('reset-mfa error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
