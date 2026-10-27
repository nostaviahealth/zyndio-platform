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
    { kind: 'one', telehealthPatientId: 'th_test_jr_001' },
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
