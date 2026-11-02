import { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'

// Goes through public.write_audit_log() (not the internal _audit_log_insert)
// so the same guarded entry point used by every other caller applies here
// too; service_role is the one caller write_audit_log() trusts unconditionally.
export async function writeAuditLog(
  admin: SupabaseClient,
  params: {
    eventType: string
    actorUserId: string | null
    targetUserId: string | null
    orgId: string | null
    metadata?: Record<string, unknown>
  }
): Promise<void> {
  const { error } = await admin.rpc('write_audit_log', {
    p_event_type: params.eventType,
    p_actor_user_id: params.actorUserId,
    p_target_user_id: params.targetUserId,
    p_org_id: params.orgId,
    p_metadata: params.metadata ?? {},
  })
  if (error) throw error
}

// notification_outbox has forced RLS with zero policies for anon/authenticated
// (see supabase/migrations/20261026120100_tc005_rls.sql) - only the
// service-role client used here can write to it. No real sending in this
// card; this row is the stand-in a real email/SMS provider would consume.
export async function insertNotification(
  admin: SupabaseClient,
  params: {
    userId: string | null
    orgId: string | null
    type: string
    payload?: Record<string, unknown>
  }
): Promise<{ id: string }> {
  const { data, error } = await admin
    .from('notification_outbox')
    .insert({
      user_id: params.userId,
      org_id: params.orgId,
      type: params.type,
      payload: params.payload ?? {},
    })
    .select('id')
    .single()
  if (error) throw error
  return { id: data.id as string }
}
