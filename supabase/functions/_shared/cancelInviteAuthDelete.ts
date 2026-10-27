import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { writeAuditLog } from './auditAndNotify.ts'

export const AUTH_DELETE_SKIP_LOOKUP_EVENT =
  'invite_cancel_auth_delete_skipped_lookup_error'

export type AuthDeleteGuard = {
  patient: boolean
  platformAdmin: boolean
  selfSignup: boolean
}

export type AuthDeleteDecision =
  | { kind: 'deleted' }
  | { kind: 'skip_protected'; guard: AuthDeleteGuard }
  | { kind: 'skip_lookup_error'; table: string; message: string }
  | { kind: 'delete_failed'; message: string }

type GuardLoad =
  | { ok: true; guard: AuthDeleteGuard }
  | { ok: false; table: string; message: string }

export async function loadAuthDeleteGuard(
  admin: SupabaseClient,
  userId: string,
): Promise<GuardLoad> {
  const [patientRes, platformAdminRes, selfSignupRes] = await Promise.all([
    admin.from('patients').select('id').eq('id', userId).maybeSingle(),
    admin.from('platform_admins').select('user_id').eq('user_id', userId).maybeSingle(),
    admin.from('patient_self_signups').select('user_id').eq('user_id', userId).maybeSingle(),
  ])

  if (patientRes.error) {
    return { ok: false, table: 'patients', message: patientRes.error.message }
  }
  if (platformAdminRes.error) {
    return { ok: false, table: 'platform_admins', message: platformAdminRes.error.message }
  }
  if (selfSignupRes.error) {
    return { ok: false, table: 'patient_self_signups', message: selfSignupRes.error.message }
  }

  return {
    ok: true,
    guard: {
      patient: !!patientRes.data,
      platformAdmin: !!platformAdminRes.data,
      selfSignup: !!selfSignupRes.data,
    },
  }
}

export function shouldSkipAuthDelete(guard: AuthDeleteGuard): boolean {
  return guard.patient || guard.platformAdmin || guard.selfSignup
}

/** Clara L29/L30/L31: run the post-cancel auth delete with protection checks. */
export async function decideCancelAuthDelete(
  admin: SupabaseClient,
  params: { targetUserId: string; actorUserId: string; orgId: string },
): Promise<AuthDeleteDecision> {
  const loaded = await loadAuthDeleteGuard(admin, params.targetUserId)
  if (!loaded.ok) {
    await writeAuditLog(admin, {
      eventType: AUTH_DELETE_SKIP_LOOKUP_EVENT,
      actorUserId: params.actorUserId,
      targetUserId: params.targetUserId,
      orgId: params.orgId,
      metadata: { table: loaded.table, error: loaded.message, reason: AUTH_DELETE_SKIP_LOOKUP_EVENT },
    })
    return { kind: 'skip_lookup_error', table: loaded.table, message: loaded.message }
  }

  if (shouldSkipAuthDelete(loaded.guard)) {
    return { kind: 'skip_protected', guard: loaded.guard }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(params.targetUserId)
  if (deleteError) {
    await recordAuthDeleteFailure(admin, {
      actorUserId: params.actorUserId,
      targetUserId: params.targetUserId,
      orgId: params.orgId,
      message: deleteError.message ?? String(deleteError),
    })
    return { kind: 'delete_failed', message: deleteError.message ?? String(deleteError) }
  }
  return { kind: 'deleted' }
}

/** Clara L30: leftover from a cancel whose auth delete failed — no membership,
 * no patient / platform-admin / self-signup, and at least one cancelled invite. */
export async function isCancelledInviteLeftover(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const loaded = await loadAuthDeleteGuard(admin, userId)
  // Lookup failure: do not treat as a safe leftover (M6 stay-closed).
  if (!loaded.ok) return false
  if (shouldSkipAuthDelete(loaded.guard)) return false

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
