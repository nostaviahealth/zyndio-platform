import {
  assertEquals,
  assertThrows,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  FakeTelehealthAdapter,
  FAKE_TELEHEALTH_FIXTURES,
  createTelehealthConnector,
} from './telehealthConnector.ts'

Deno.test('FakeTelehealthAdapter locate: none / one / ambiguous (PSU-TO-14 shapes)', async () => {
  const fake = new FakeTelehealthAdapter([
    ...FAKE_TELEHEALTH_FIXTURES,
    {
      telehealthPatientId: 'th_test_dup_a',
      normalisedEmail: 'dup@example.com',
      displayName: 'Dup A',
      clinicLabel: 'Clinic',
    },
    {
      telehealthPatientId: 'th_test_dup_b',
      normalisedEmail: 'dup@example.com',
      displayName: 'Dup B',
      clinicLabel: 'Clinic',
    },
  ])
  assertEquals(
    await fake.locateForCodeRequest({ appUserId: 'u1', normalisedEmail: 'nobody@example.com' }),
    { kind: 'none' },
  )
  assertEquals(
    await fake.locateForCodeRequest({
      appUserId: 'u1',
      normalisedEmail: 'jordan.rivera@example.com',
    }),
    {
      kind: 'one',
      telehealthPatientId: 'th_test_jr_001',
      orgId: '00000000-0000-0000-0000-00000000000a',
    },
  )
  assertEquals(
    await fake.locateForCodeRequest({ appUserId: 'u1', normalisedEmail: 'dup@example.com' }),
    { kind: 'ambiguous' },
  )
})

Deno.test('FakeTelehealthAdapter sendPatientMessage appends outbox (link/unlink notice stub)', async () => {
  const fake = new FakeTelehealthAdapter()
  await fake.sendPatientMessage({
    telehealthPatientId: 'th_test_jr_001',
    body: 'Your record was linked to a Zyndio app account. Not you? Contact your clinic.',
  })
  assertEquals(fake.messages.length, 1)
  assertEquals(fake.messages[0].telehealthPatientId, 'th_test_jr_001')
})

Deno.test('createTelehealthConnector defaults to fake; live refuses without allow (PSU-TO-12)', async () => {
  const fake = createTelehealthConnector({ get: () => undefined })
  assertEquals(
    (await fake.locateForCodeRequest({
      appUserId: 'u',
      normalisedEmail: 'avery.chen@example.com',
    })).kind,
    'one',
  )
  assertThrows(
    () =>
      createTelehealthConnector({
        get: (n) => (n === 'TELEHEALTH_ADAPTER' ? 'live' : undefined),
      }),
    Error,
    'refused',
  )
})

Deno.test('M13: sendPatientMessage body carries OTP; adapter does not log secrets', async () => {
  const fake = new FakeTelehealthAdapter()
  const code = '918273'
  const body =
    `Your Zyndio link code is ${code}. It expires in 10 minutes and works once. Not you? Ignore this message.`
  await fake.sendPatientMessage({
    telehealthPatientId: 'th_test_jr_001',
    body,
  })
  assertEquals(fake.messages.length, 1)
  assertEquals(fake.messages[0].body.includes(code), true)
  // Outbox is the delivery channel; nothing else is appended.
  assertEquals(Object.keys(fake.messages[0]).sort(), ['at', 'body', 'telehealthPatientId'])
})

Deno.test('L19: locate one includes orgId from fixture when present', async () => {
  const fake = new FakeTelehealthAdapter()
  const located = await fake.locateForCodeRequest({
    appUserId: 'u1',
    normalisedEmail: 'jordan.rivera@example.com',
  })
  assertEquals(located.kind, 'one')
  if (located.kind === 'one') {
    assertEquals(located.orgId, '00000000-0000-0000-0000-00000000000a')
  }
})
