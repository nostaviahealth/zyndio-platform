import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { renderLoginCodeEmail, renderNotificationEmail } from './emailTemplates.ts'

Deno.test('login code email: code, expiry and safety line in both parts', () => {
  const email = renderLoginCodeEmail({ code: '482913', expiresInMinutes: 10 })!
  assertEquals(email.subject, '482913 is your Zyndio sign-in code')
  for (const body of [email.text, email.html]) {
    assertStringIncludes(body, '482 913')
    assertStringIncludes(body, '10 minutes')
    assertStringIncludes(body, 'never ask you for')
  }
})

Deno.test('login code email: no health information (APP-10)', () => {
  const email = renderLoginCodeEmail({ code: '482913', expiresInMinutes: 10 })!
  // What the reader sees: subject, text part and the HTML with markup (and
  // its CSS, e.g. font-weight) stripped.
  const visibleHtml = email.html.replace(/<style[\s\S]*?<\/style>/g, '').replace(/<[^>]+>/g, ' ')
  const all = `${email.subject} ${email.text} ${visibleHtml}`.toLowerCase()
  for (const word of ['lab', 'result', 'biomarker', 'glp', 'weight', 'diagnos', 'clinic', 'treatment', 'scan']) {
    assert(!all.includes(word), `email must not mention "${word}"`)
  }
})

Deno.test('login code email: refuses a malformed code or expiry', () => {
  assertEquals(renderLoginCodeEmail({ code: '12345', expiresInMinutes: 10 }), null)
  assertEquals(renderLoginCodeEmail({ code: '12345a', expiresInMinutes: 10 }), null)
  assertEquals(renderLoginCodeEmail({ code: '123456', expiresInMinutes: 0 }), null)
})

Deno.test('renderNotificationEmail: maps the outbox payload; unknown types stay on the stub', () => {
  const email = renderNotificationEmail('patient_login_code', { email: 'a@example.test', token: '482913', expires_in_minutes: 10 })
  assertStringIncludes(email!.text, '482 913')
  assertEquals(renderNotificationEmail('patient_login_code', { token: null, expires_in_minutes: 10 }), null)
  assertEquals(renderNotificationEmail('invite', { token: 'x' }), null)
})
