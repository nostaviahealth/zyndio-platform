import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  isSendableTelehealthOutboxRow,
  listPendingTelehealthOutbox,
  PENDING_TELEHEALTH_OUTBOX_FILTER,
} from './telehealthOutbox.ts'

Deno.test('M15: PENDING filter requires delivered_at and scrubbed_at null', () => {
  assertEquals(PENDING_TELEHEALTH_OUTBOX_FILTER.delivered_at, null)
  assertEquals(PENDING_TELEHEALTH_OUTBOX_FILTER.scrubbed_at, null)
})

Deno.test('M15: sender skips scrubbed / delivered / "code removed" rows', () => {
  assertEquals(
    isSendableTelehealthOutboxRow({
      delivered_at: null,
      scrubbed_at: null,
      body: 'Your Zyndio link code is 123456. It expires in 10 minutes and works once. Not you? Ignore this message.',
    }),
    true,
  )
  assertEquals(
    isSendableTelehealthOutboxRow({
      delivered_at: null,
      scrubbed_at: '2026-10-27T10:00:00Z',
      body: 'code removed',
    }),
    false,
  )
  assertEquals(
    isSendableTelehealthOutboxRow({
      delivered_at: '2026-10-27T10:00:00Z',
      scrubbed_at: null,
      body: 'Your record was linked to a Zyndio app account. Not you? Contact your clinic.',
    }),
    false,
  )
  assertEquals(
    isSendableTelehealthOutboxRow({
      delivered_at: null,
      scrubbed_at: null,
      body: 'code removed',
    }),
    false,
  )
})

Deno.test('M15: listPendingTelehealthOutbox drops scrubbed rows from RPC payload', async () => {
  const admin = {
    async rpc() {
      return {
        data: [
          {
            id: '11111111-1111-1111-1111-111111111111',
            telehealth_patient_id: 'th_test_notice',
            body: 'Your record was linked to a Zyndio app account. Not you? Contact your clinic.',
            message_type: 'notice' as const,
            created_at: '2026-10-27T09:00:00Z',
          },
          {
            id: '22222222-2222-2222-2222-222222222222',
            telehealth_patient_id: 'th_test_scrubbed',
            body: 'code removed',
            message_type: 'code' as const,
            created_at: '2026-10-27T09:00:00Z',
            // RPC should already exclude these; belt-and-braces if a row leaks.
          },
        ],
        error: null,
      }
    },
  }
  // Simulate a leaked scrubbed row by forcing isSendable on body alone via the helper.
  const rows = await listPendingTelehealthOutbox(admin)
  assertEquals(rows.length, 1)
  assertEquals(rows[0].telehealth_patient_id, 'th_test_notice')
})
