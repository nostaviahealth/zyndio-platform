import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { redactSentPayload, stubLogLine } from './emailStub.ts'

Deno.test('stubLogLine names the template and recipient, nothing else', () => {
  assertEquals(stubLogLine('invite', 'alice@example.test'), '[email-stub] sent_stub template=invite to=alice@example.test')
})

Deno.test('redactSentPayload nulls the token for an invite payload', () => {
  assertEquals(redactSentPayload('invite', { email: 'alice@example.test', token: 'super-secret-token' }), {
    email: 'alice@example.test',
    token: null,
  })
})

Deno.test('redactSentPayload leaves non-invite payloads untouched', () => {
  const payload = { foo: 'bar' }
  assertEquals(redactSentPayload('mfa_reset', payload), payload)
})

Deno.test('redactSentPayload is a no-op when an invite payload has no token key', () => {
  const payload = { email: 'alice@example.test' }
  assertEquals(redactSentPayload('invite', payload), payload)
})
