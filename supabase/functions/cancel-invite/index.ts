// Org-admin-only: cancel a still-pending invite in the caller's clinic.
// Revokes the token immediately (accept-invite then returns
// invalid_or_expired_invite), removes the org_members row so the admin
// table no longer lists them, audits invite_cancelled, and deletes the
// never-accepted auth.users row so a later re-invite is not tripped by M6.
//
// Clara L29: skip auth delete when the account has a patient row, a
// platform-admin row, or a self-signup marker.
// Clara L30: if deleteUser fails, audit invite_cancel_auth_delete_failed and
// still return ok (invite-user can re-attach a cancelled-invite leftover).
// Clara L31: if a protection lookup errors, skip delete and audit
// invite_cancel_auth_delete_skipped_lookup_error (do not treat as clear).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireOrgAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { isValidUuid } from '../_shared/validation.ts'
import { decideCancelAuthDelete } from '../_shared/cancelInviteAuthDelete.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const { actor, admin } = await requireOrgAdminActor(req)

    const body = await req.json().catch(() => ({}))
    const targetUserId = body.target_user_id

    if (!isValidUuid(targetUserId)) {
      return jsonResponse(req, { error: 'invalid_request' }, 400)
    }

    // Same-clinic check before the RPC so a cross-clinic target looks like
    // not_found (no enumeration of other orgs' member ids).
    const { data: target } = await admin
      .from('org_members')
      .select('org_id, status')
      .eq('user_id', targetUserId)
      .maybeSingle()

    if (!target || target.org_id !== actor.orgId) {
      return jsonResponse(req, { error: 'not_found' }, 404)
    }
    if (target.status !== 'invited') {
      return jsonResponse(req, { error: 'not_invited' }, 409)
    }

    const { data: result, error: finalizeError } = await admin.rpc('finalize_invite_cancel', {
      p_target_user_id: targetUserId,
      p_actor_user_id: actor.userId,
      p_org_id: actor.orgId,
    })

    if (finalizeError) {
      if (finalizeError.code === 'P0002') {
        return jsonResponse(req, { error: 'not_found' }, 404)
      }
      if (finalizeError.code === 'P0001') {
        return jsonResponse(req, { error: 'not_invited' }, 409)
      }
      console.error('cancel-invite: finalize_invite_cancel failed', finalizeError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    try {
      const decision = await decideCancelAuthDelete(admin, {
        targetUserId,
        actorUserId: actor.userId,
        orgId: actor.orgId,
      })
      if (decision.kind === 'skip_protected') {
        console.info('cancel-invite: skipping auth delete (protected account)', {
          targetUserId,
          ...decision.guard,
        })
      } else if (decision.kind === 'skip_lookup_error') {
        console.error('cancel-invite: skipping auth delete (lookup error)', decision)
      } else if (decision.kind === 'delete_failed') {
        console.error('cancel-invite: deleteUser failed', decision.message)
      }
    } catch (authDeleteErr) {
      console.error('cancel-invite: auth delete decision failed', authDeleteErr)
    }

    const payload = (result ?? {}) as { email?: string; role?: string; full_name?: string }
    return jsonResponse(req, {
      status: 'ok',
      email: payload.email ?? null,
      full_name: payload.full_name ?? null,
      role: payload.role ?? null,
    })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('cancel-invite error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
