// Org-admin-only. public.enforce_last_admin (schema migration trigger)
// rejects deactivating the last active org_admin - surfaced here as a
// specific, non-enumeration-sensitive error since the caller is already an
// authenticated admin of this org.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireOrgAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { isValidUuid } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const { actor, admin } = await requireOrgAdminActor(req)

    const body = await req.json().catch(() => ({}))
    const targetUserId = body.target_user_id

    if (!isValidUuid(targetUserId)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    const { data: target } = await admin
      .from('org_members')
      .select('org_id, status')
      .eq('user_id', targetUserId)
      .maybeSingle()

    if (!target || target.org_id !== actor.orgId) {
      return jsonResponse(req, { error: 'not_found' }, 404)
    }

    // B3 / M4: status flip, invite revoke, force sign-out, audit and outbox
    // all happen inside one SECURITY DEFINER transaction (finalize_deactivation)
    // so a failure anywhere rolls back the whole thing instead of leaving a
    // deactivated member with no audit row or a still-live session.
    const { error: finalizeError } = await admin.rpc('finalize_deactivation', {
      p_target_user_id: targetUserId,
      p_actor_user_id: actor.userId,
      p_org_id: actor.orgId,
    })

    if (finalizeError) {
      if (finalizeError.code === 'P0001') {
        return jsonResponse(req, { error: 'cannot_deactivate_last_admin' }, 409)
      }
      console.error('deactivate-user: finalize_deactivation failed', finalizeError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('deactivate-user error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
