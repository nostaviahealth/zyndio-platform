import { assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { PatientInviteError, parseIssueInviteResult, sendPatientInvite } from './patientInvite.ts'
import { isSelfSignupOpen } from './selfSignup.ts'

function fakeRpc(result: { data: unknown; error: unknown }) {
  const calls: Array<{ fn: string; args: unknown }> = []
  const client = {
    rpc(fn: string, args: unknown) {
      calls.push({ fn, args })
      return Promise.resolve(result)
    },
  } as unknown as SupabaseClient
  return { client, calls }
}

Deno.test('parseIssueInviteResult needs invite_id, org_id and email', () => {
  assertEquals(parseIssueInviteResult({ invite_id: 'i', org_id: 'o', email: 'e@example.test' }), {
    inviteId: 'i',
    orgId: 'o',
    email: 'e@example.test',
  })
  assertEquals(parseIssueInviteResult({ invite_id: 'i', org_id: 'o' }), null)
  assertEquals(parseIssueInviteResult(null), null)
})

Deno.test('sendPatientInvite records the invite then queues a credential-free patient_invite email', async () => {
  const { client, calls } = fakeRpc({
    data: { invite_id: 'inv-1', org_id: 'org-a', email: 'patient@example.test' },
    error: null,
  })
  const sent: unknown[] = []
  const result = await sendPatientInvite(
    client,
    { patientId: 'p-1', invitedBy: 'staff-1', source: 'staff' },
    (_admin, params) => {
      sent.push(params)
      return Promise.resolve({ id: 'n-1' })
    },
  )
  assertEquals(calls, [{
    fn: 'issue_patient_invite',
    args: { p_patient_id: 'p-1', p_invited_by: 'staff-1', p_source: 'staff' },
  }])
  assertEquals(sent, [{
    userId: 'p-1',
    orgId: 'org-a',
    type: 'patient_invite',
    payload: { email: 'patient@example.test', invite_id: 'inv-1' },
  }])
  assertEquals(result, { inviteId: 'inv-1', orgId: 'org-a', email: 'patient@example.test' })
})

Deno.test('sendPatientInvite sends nothing when the invite could not be recorded', async () => {
  const { client } = fakeRpc({ data: null, error: { code: '42501' } })
  let sent = 0
  await assertRejects(
    () =>
      sendPatientInvite(client, { patientId: 'p-1', invitedBy: null, source: 'api' }, () => {
        sent++
        return Promise.resolve({ id: 'n' })
      }),
    PatientInviteError,
  )
  assertEquals(sent, 0)
})

const ORG = '00000000-0000-0000-0000-00000000000a'
const env = (orgId?: string) => ({ get: (k: string) => (k === 'ZYNDIO_DEFAULT_ORG_ID' ? orgId : undefined) })

Deno.test('isSelfSignupOpen is true only when the configured org turned it on', async () => {
  const open = fakeRpc({ data: true, error: null })
  assertEquals(await isSelfSignupOpen(open.client, env(ORG)), true)
  assertEquals(open.calls, [{ fn: 'patient_self_signup_open', args: { p_org_id: ORG } }])

  assertEquals(await isSelfSignupOpen(fakeRpc({ data: false, error: null }).client, env(ORG)), false)
})

Deno.test('isSelfSignupOpen is closed with no org, a malformed org, or a lookup error', async () => {
  const never = fakeRpc({ data: true, error: null })
  assertEquals(await isSelfSignupOpen(never.client, env(undefined)), false)
  assertEquals(await isSelfSignupOpen(never.client, env('not-a-uuid')), false)
  assertEquals(never.calls.length, 0, 'no lookup without a valid org id')
  assertEquals(await isSelfSignupOpen(fakeRpc({ data: true, error: { code: 'XX000' } }).client, env(ORG)), false)
})
