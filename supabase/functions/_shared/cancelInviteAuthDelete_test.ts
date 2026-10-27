import {
  assertEquals,
  assertFalse,
  assert,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  shouldSkipAuthDelete,
  recordAuthDeleteFailure,
} from './cancelInviteAuthDelete.ts'

Deno.test('Clara L29: shouldSkipAuthDelete is true when any guard fires', () => {
  assert(shouldSkipAuthDelete({ patient: true, platformAdmin: false, selfSignup: false }))
  assert(shouldSkipAuthDelete({ patient: false, platformAdmin: true, selfSignup: false }))
  assert(shouldSkipAuthDelete({ patient: false, platformAdmin: false, selfSignup: true }))
})

Deno.test('Clara L29: shouldSkipAuthDelete is false when all guards clear', () => {
  assertFalse(shouldSkipAuthDelete({ patient: false, platformAdmin: false, selfSignup: false }))
})

Deno.test('Clara L30: recordAuthDeleteFailure audits invite_cancel_auth_delete_failed', async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = []
  const admin = {
    rpc: (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args })
      return Promise.resolve({ data: null, error: null })
    },
  }
  await recordAuthDeleteFailure(admin as never, {
    actorUserId: '00000000-0000-0000-0000-0000000a0001',
    targetUserId: '00000000-0000-0000-0000-0000000a00f4',
    orgId: '00000000-0000-0000-0000-00000000000a',
    message: 'simulated delete failure',
  })
  assertEquals(calls.length, 1)
  assertEquals(calls[0].name, 'write_audit_log')
  assertEquals(calls[0].args.p_event_type, 'invite_cancel_auth_delete_failed')
  assertEquals(calls[0].args.p_metadata, { error: 'simulated delete failure' })
})
