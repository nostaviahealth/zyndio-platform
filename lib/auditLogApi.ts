import { supabase } from './supabase';

// POR-08: Organization Audit Log API (callable ONLY by active org_admin at AAL2).

export interface AuditLogEntry {
  id: number;
  action: string;
  actorId: string | null;
  targetId: string | null;
  createdAt: string;
  metadata: Record<string, unknown>;
}

export interface ListAuditLogParams {
  limit?: number;
  actionFilter?: string | null;
}

export interface AuditLogApi {
  listOrgAuditLog(params?: ListAuditLogParams): Promise<AuditLogEntry[]>;
}

type Raw = Record<string, unknown>;

export function mapAuditLogRow(r: Raw): AuditLogEntry {
  return {
    id: typeof r.id === 'number' ? r.id : Number(r.id ?? 0),
    action: String(r.action ?? r.event_type ?? ''),
    actorId: r.actor_id ? String(r.actor_id) : null,
    targetId: r.target_id ? String(r.target_id) : null,
    createdAt: String(r.created_at ?? ''),
    metadata:
      r.metadata && typeof r.metadata === 'object' && !Array.isArray(r.metadata)
        ? (r.metadata as Record<string, unknown>)
        : {},
  };
}

export async function listOrgAuditLog(
  params: ListAuditLogParams = {}
): Promise<AuditLogEntry[]> {
  const { data, error } = await supabase.rpc('list_org_audit_log', {
    p_limit: params.limit ?? 100,
    p_action_filter: params.actionFilter && params.actionFilter.trim() !== '' ? params.actionFilter.trim() : null,
  });
  if (error) throw error;
  const rows = Array.isArray(data) ? (data as Raw[]) : [];
  return rows.map(mapAuditLogRow);
}

export const supabaseAuditLogApi: AuditLogApi = {
  listOrgAuditLog,
};
