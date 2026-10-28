// Zyndio-admin-only (Henry ruling: an org admin may only *request* a reset,
// via the request_mfa_reset() RPC - see recovery-reenrol/requireOrgAdminActor
// for that path). Never the caller's own row (server-enforced, not just a
// hidden UI button). Removes the target's TOTP factor(s) and old recovery
// codes, flags them for mandatory re-enrollment, forces a global sign-out,
// and audits + notifies.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireZyndioAdminActor } from '../_shared/requireOrgAdminActor.ts'
import { isValidUuid } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { actor, admin } = await requireZyndioAdminActor(req)

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

    if (!target) {
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

    // L9: delete the target's old recovery codes too - harmless once the
    // factor is gone (a code only sets the re-enrol flag), but hygiene.
    const { error: deleteCodesError } = await admin.from('mfa_recovery_codes').delete().eq('user_id', targetUserId)
    if (deleteCodesError) {
      console.error('reset-mfa: deleting old recovery codes failed', deleteCodesError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    // B3 / M4: flag, force sign-out, audit and outbox all happen inside one
    // SECURITY DEFINER transaction (finalize_mfa_reset), called after the
    // factor deletes above - a failure anywhere rolls back the whole thing
    // instead of (as before) silently swallowing a sign-out or audit failure
    // and returning 200 regardless.
    const { error: finalizeError } = await admin.rpc('finalize_mfa_reset', {
      p_target_user_id: targetUserId,
      p_actor_user_id: actor.userId,
      p_org_id: target.org_id,
    })
    if (finalizeError) {
      console.error('reset-mfa: finalize_mfa_reset failed', finalizeError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    return jsonResponse({ status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('reset-mfa error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
