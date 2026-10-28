// Self-service only, aal1 is fine - this is precisely the state a just-used
// recovery code leaves the caller in (OVERRIDES #3 + Henry's answer #10: a
// recovery-code session never grants aal2 directly; the person must
// immediately re-enrol an authenticator instead). Acts only on the caller's
// own row - there is no target_user_id, by design: an org admin resetting
// someone else's MFA is reset-mfa, a different, admin-only function.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireAuthenticatedActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { userId, admin } = await requireAuthenticatedActor(req)

    const { data: flag, error: flagError } = await admin
      .from('mfa_reenrollment_required')
      .select('user_id')
      .eq('user_id', userId)
      .maybeSingle()
    if (flagError) {
      console.error('recovery-reenrol: mfa_reenrollment_required lookup failed', flagError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    if (!flag) {
      // Nothing pending - not an error, just nothing to do (e.g. already
      // completed re-enrollment, or never used a recovery code).
      return jsonResponse({ status: 'ok', reenrollment_required: false })
    }

    const { data: factorData, error: factorListError } = await admin.auth.admin.mfa.listFactors({
      userId,
    })
    if (factorListError) {
      console.error('recovery-reenrol: listFactors failed', factorListError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    for (const factor of factorData?.factors ?? []) {
      const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({
        userId,
        id: factor.id,
      })
      if (deleteError) {
        console.error('recovery-reenrol: deleteFactor failed', deleteError)
        return jsonResponse({ error: 'internal_error' }, 500)
      }
    }

    const { data: member } = await admin
      .from('org_members')
      .select('org_id')
      .eq('user_id', userId)
      .maybeSingle()

    await writeAuditLog(admin, {
      eventType: 're_enrolment_started',
      actorUserId: userId,
      targetUserId: userId,
      orgId: member?.org_id ?? null,
    })

    return jsonResponse({ status: 'ok', reenrollment_required: true })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse({ error: err.message }, err.status)
    console.error('recovery-reenrol error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
