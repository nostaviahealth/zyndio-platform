// B5 / Henry ruling 3: real sending is TC-006. Until then, every Edge
// Function that writes a notification_outbox row also calls
// sendNotificationStub() right after, so the review's ask - "a logged,
// tested STUB sender" - is actually exercised end to end, not just a row
// sitting at status='pending' forever.
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface OutboxRow {
  id: string
  userId: string | null
  type: string
  payload: Record<string, unknown>
}

// Pure: never logs or stores the payload itself, only type + recipient (L8
// also asks to never log a token). Exported separately from the impure
// orchestration below so it can be deno-tested without a live Supabase
// client.
export function stubLogLine(type: string, recipient: string): string {
  return `[email-stub] sent_stub template=${type} to=${recipient}`
}

// Pure: nulls the plaintext invite token out of a payload once "sent" (L8) -
// nothing legitimate needs it again after this point. Every other
// notification type's payload passes through unchanged.
export function redactSentPayload(type: string, payload: Record<string, unknown>): Record<string, unknown> {
  if (type !== 'invite' || !('token' in payload)) return payload
  return { ...payload, token: null }
}

export async function sendNotificationStub(admin: SupabaseClient, row: OutboxRow): Promise<void> {
  let recipient = 'unknown'
  if (row.userId) {
    const { data } = await admin.auth.admin.getUserById(row.userId)
    recipient = data?.user?.email ?? 'unknown'
  }
  console.log(stubLogLine(row.type, recipient))

  const { error } = await admin
    .from('notification_outbox')
    .update({ status: 'sent_stub', payload: redactSentPayload(row.type, row.payload) })
    .eq('id', row.id)
  if (error) throw error
}
