import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { writeAuditLog } from './auditAndNotify.ts'

export type AuthDeleteGuard = {
  patient: boolean
  platformAdmin: boolean
  selfSignup: boolean
}

export async function loadAuthDeleteGuard(
  admin: SupabaseClient,
  userId: string,
): Promise<AuthDeleteGuard> {
  const [{ data: patientRow }, { data: platformAdminRow }, { data: selfSignupRow }] =
    await Promise.all([
      admin.from('patients').select('id').eq('id', userId).maybeSingle(),
      admin.from('platform_admins').select('user_id').eq('user_id', userId).maybeSingle(),
      admin.from('patient_self_signups').select('user_id').eq('user_id', userId).maybeSingle(),
    ])
  return {
    patient: !!patientRow,
    platformAdmin: !!platformAdminRow,
    selfSignup: !!selfSignupRow,
  }
}

export function shouldSkipAuthDelete(guard: AuthDeleteGuard): boolean {
  return guard.patient || guard.platformAdmin || guard.selfSignup
}

/** Clara L30: leftover from a cancel whose auth delete failed — no membership,
 * no patient / platform-admin / self-signup, and at least one cancelled invite. */
export async function isCancelledInviteLeftover(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const guard = await loadAuthDeleteGuard(admin, userId)
  if (shouldSkipAuthDelete(guard)) return false

  const { data: member } = await admin
    .from('org_members')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle()
  if (member) return false

  const { data: cancelled, error } = await admin
    .from('invites')
    .select('id')
    .eq('user_id', userId)
    .not('revoked_at', 'is', null)
    .limit(1)
  if (error) throw error
  return (cancelled?.length ?? 0) > 0
}

export async function recordAuthDeleteFailure(
  admin: SupabaseClient,
  params: {
    actorUserId: string
    targetUserId: string
    orgId: string
    message: string
  },
): Promise<void> {
  await writeAuditLog(admin, {
    eventType: 'invite_cancel_auth_delete_failed',
    actorUserId: params.actorUserId,
    targetUserId: params.targetUserId,
    orgId: params.orgId,
    metadata: { error: params.message },
  })
}
