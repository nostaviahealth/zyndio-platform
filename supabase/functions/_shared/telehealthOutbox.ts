// Clara M15: drain query for telehealth_message_outbox.
// Pending = not delivered AND not scrubbed. Scrubbed code rows keep body
// "code removed" in the DB for audit, but must never be sent to a patient.

export type PendingTelehealthOutboxRow = {
  id: string
  telehealth_patient_id: string
  body: string
  message_type: 'code' | 'notice'
  created_at: string
}

/** PostgREST / RPC filter the sender must apply (defense in depth alongside list_pending_telehealth_outbox). */
export const PENDING_TELEHEALTH_OUTBOX_FILTER = {
  delivered_at: null as null,
  scrubbed_at: null as null,
} as const

export function isSendableTelehealthOutboxRow(row: {
  delivered_at?: string | null
  scrubbed_at?: string | null
  body?: string
}): boolean {
  if (row.delivered_at != null) return false
  if (row.scrubbed_at != null) return false
  // Belt-and-braces: never deliver the scrub placeholder even if a row slips through.
  if (row.body === 'code removed') return false
  return true
}

type RpcClient = {
  rpc(
    fn: string,
    args?: Record<string, unknown>,
  ): Promise<{ data: PendingTelehealthOutboxRow[] | null; error: { message: string } | null }>
}

/** Preferred sender entry: SQL list_pending_telehealth_outbox (service_role). */
export async function listPendingTelehealthOutbox(
  admin: RpcClient,
): Promise<PendingTelehealthOutboxRow[]> {
  const { data, error } = await admin.rpc('list_pending_telehealth_outbox')
  if (error) throw new Error(`list_pending_telehealth_outbox: ${error.message}`)
  return (data ?? []).filter(isSendableTelehealthOutboxRow)
}
