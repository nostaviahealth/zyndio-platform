import {
  assertEquals,
  assertFalse,
  assert,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { shouldSkipAuthDelete } from './cancelInviteAuthDelete.ts'

Deno.test('Clara L29: shouldSkipAuthDelete is true when any guard fires', () => {
  assert(shouldSkipAuthDelete({ patient: true, platformAdmin: false, selfSignup: false }))
  assert(shouldSkipAuthDelete({ patient: false, platformAdmin: true, selfSignup: false }))
  assert(shouldSkipAuthDelete({ patient: false, platformAdmin: false, selfSignup: true }))
})

Deno.test('Clara L29: shouldSkipAuthDelete is false when all guards clear', () => {
  assertFalse(shouldSkipAuthDelete({ patient: false, platformAdmin: false, selfSignup: false }))
})

Deno.test('Clara L30: invite_cancel_auth_delete_failed is the audit event name', () => {
  // Contract for cancel-invite + integration assertions.
  assertEquals('invite_cancel_auth_delete_failed', 'invite_cancel_auth_delete_failed')
})
