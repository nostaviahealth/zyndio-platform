import { assertEquals, assertExists } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { deliverNotification, redactSentPayload, sendNotificationStub, stubLogLine } from './emailStub.ts'

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

Deno.test('redactSentPayload nulls the token for verify_email and password_reset payloads too', () => {
  assertEquals(redactSentPayload('verify_email', { email: 'alice@example.test', token: 't' }), {
    email: 'alice@example.test',
    token: null,
  })
  assertEquals(redactSentPayload('password_reset', { email: 'alice@example.test', token: 't' }), {
    email: 'alice@example.test',
    token: null,
  })
})

Deno.test('redactSentPayload nulls the emailed sign-in code once sent (APP-01)', () => {
  assertEquals(redactSentPayload('patient_login_code', { email: 'alice@example.test', token: '123456' }), {
    email: 'alice@example.test',
    token: null,
  })
})

// TC-018 item 6 (L8): sendNotificationStub is the only path that scrubs a
// token *immediately* (cron is the 15-minute backstop, see the pgTAP scrub
// test) - it must stamp scrubbed_at in the same update so the cron sweep
// skips an already-handled row instead of re-scanning it forever.
Deno.test('sendNotificationStub sets scrubbed_at in the same update that redacts the token', async () => {
  const updates: Array<Record<string, unknown>> = []
  const admin = {
    auth: { admin: { getUserById: async () => ({ data: { user: { email: 'alice@example.test' } } }) } },
    from: (_table: string) => ({
      update: (vals: Record<string, unknown>) => {
        updates.push(vals)
        return { eq: async () => ({ error: null }) }
      },
    }),
  }
  await sendNotificationStub(admin as never, {
    id: 'row-1',
    userId: 'user-1',
    type: 'invite',
    payload: { email: 'alice@example.test', token: 'super-secret-token' },
  })
  assertEquals(updates.length, 1)
  assertEquals(updates[0].payload, { email: 'alice@example.test', token: null })
  assertExists(updates[0].scrubbed_at)
})

// TC-006: deliverNotification sends over SMTP when configured and falls back
// to the stub otherwise; the stored token is redacted in every outcome.
function fakeAdmin() {
  const updates: Array<Record<string, unknown>> = []
  const admin = {
    auth: { admin: { getUserById: async () => ({ data: { user: { email: 'jordan.rivera@example.test' } } }) } },
    from: (_table: string) => ({
      update: (vals: Record<string, unknown>) => {
        updates.push(vals)
        return { eq: async () => ({ error: null }) }
      },
    }),
  }
  return { admin: admin as never, updates }
}
const smtpEnv = {
  get: (k: string) =>
    ({ SMTP_HOST: 'smtp.example.test', SMTP_USERNAME: 'u', SMTP_PASSWORD: 'p', SMTP_FROM: 'care@example.test' } as Record<string, string>)[k],
}
const codeRow = {
  id: 'row-9',
  userId: 'user-9',
  type: 'patient_login_code',
  payload: { email: 'jordan.rivera@example.test', token: '482913', expires_in_minutes: 10 },
}

Deno.test('deliverNotification: sends the login code by SMTP, then marks sent and redacts', async () => {
  const { admin, updates } = fakeAdmin()
  const sent: Array<{ to: string; subject: string }> = []
  const status = await deliverNotification(admin, codeRow, {
    env: smtpEnv,
    send: async (_cfg, m) => {
      sent.push({ to: m.to, subject: m.subject })
    },
  })
  assertEquals(status, 'sent')
  assertEquals(sent, [{ to: 'jordan.rivera@example.test', subject: '482913 is your Zyndio sign-in code' }])
  assertEquals(updates[0].status, 'sent')
  assertEquals((updates[0].payload as Record<string, unknown>).token, null)
  assertExists(updates[0].scrubbed_at)
})

Deno.test('deliverNotification: a send failure marks failed and still redacts the code', async () => {
  const { admin, updates } = fakeAdmin()
  const status = await deliverNotification(admin, codeRow, {
    env: smtpEnv,
    send: async () => {
      throw new Error('boom')
    },
  })
  assertEquals(status, 'failed')
  assertEquals(updates[0].status, 'failed')
  assertEquals((updates[0].payload as Record<string, unknown>).token, null)
})

Deno.test('deliverNotification: no SMTP secrets falls back to the stub', async () => {
  const { admin, updates } = fakeAdmin()
  let called = false
  const status = await deliverNotification(admin, codeRow, {
    env: { get: () => undefined },
    send: async () => {
      called = true
    },
  })
  assertEquals(status, 'sent_stub')
  assertEquals(called, false)
  assertEquals(updates[0].status, 'sent_stub')
})

Deno.test('deliverNotification: types without a template stay on the stub even with SMTP set', async () => {
  const { admin, updates } = fakeAdmin()
  const status = await deliverNotification(admin, { id: 'r', userId: 'u', type: 'invite', payload: { token: 't' } }, {
    env: smtpEnv,
    send: async () => {
      throw new Error('should not send')
    },
  })
  assertEquals(status, 'sent_stub')
  assertEquals(updates[0].status, 'sent_stub')
})
