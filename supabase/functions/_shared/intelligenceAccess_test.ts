import { assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { decideIntelligenceAccess, loadIntelligenceCallerFacts, type IntelligenceCallerFacts } from './intelligenceAccess.ts'

// TC-021 item 9 (Henry ruling): the intelligence function is for patients
// only, and only on their own data. Every staff role (org_admin, physician,
// care_coordinator, read_only), the Zyndio platform admin, and any signed-in
// user who is not a patient get 403.
const PATIENT_A = '11111111-1111-4111-8111-111111111111'
const PATIENT_B = '22222222-2222-4222-8222-222222222222'

const patient: IntelligenceCallerFacts = { userId: PATIENT_A, isPatient: true, staffRole: null, isPlatformAdmin: false }

for (const role of ['org_admin', 'physician', 'care_coordinator', 'read_only']) {
  Deno.test(`intelligence access: staff role ${role} is 403`, () => {
    assertEquals(decideIntelligenceAccess({ ...patient, isPatient: false, staffRole: role }, undefined), {
      ok: false,
      status: 403,
      error: 'intelligence_patients_only',
    })
  })

  Deno.test(`intelligence access: staff role ${role} is 403 even with a patient marker`, () => {
    assertEquals(decideIntelligenceAccess({ ...patient, staffRole: role }, undefined).ok, false)
  })
}

Deno.test('intelligence access: Zyndio platform admin is 403', () => {
  assertEquals(decideIntelligenceAccess({ ...patient, isPatient: false, isPlatformAdmin: true }, undefined), {
    ok: false,
    status: 403,
    error: 'intelligence_patients_only',
  })
})

Deno.test('intelligence access: signed-in user who is not a patient is 403', () => {
  assertEquals(decideIntelligenceAccess({ ...patient, isPatient: false }, undefined), {
    ok: false,
    status: 403,
    error: 'intelligence_patients_only',
  })
})

Deno.test("intelligence access: a patient asking about another patient's data is 403", () => {
  assertEquals(decideIntelligenceAccess(patient, PATIENT_B), {
    ok: false,
    status: 403,
    error: 'intelligence_own_data_only',
  })
})

Deno.test('intelligence access: a non-string patient_id is 403 (no type confusion)', () => {
  assertEquals(decideIntelligenceAccess(patient, [PATIENT_A]).ok, false)
})

Deno.test('intelligence access: a patient on their own data is allowed', () => {
  assertEquals(decideIntelligenceAccess(patient, undefined), { ok: true })
  assertEquals(decideIntelligenceAccess(patient, PATIENT_A), { ok: true })
})

// Fake service-role client: answers .from(table).select(col).eq(col, id).maybeSingle()
function fakeAdmin(rows: Record<string, unknown>, failTable?: string): SupabaseClient {
  const fake = {
    from(table: string) {
      return {
        select(_cols: string) {
          return {
            eq(_col: string, _id: string) {
              return {
                maybeSingle: () =>
                  Promise.resolve(
                    table === failTable
                      ? { data: null, error: { message: 'boom' } }
                      : { data: rows[table] ?? null, error: null },
                  ),
              }
            },
          }
        },
      }
    },
  }
  return fake as unknown as SupabaseClient
}

Deno.test('intelligence caller facts: self-signup patient', async () => {
  const facts = await loadIntelligenceCallerFacts(fakeAdmin({ patient_self_signups: { user_id: PATIENT_A } }), PATIENT_A)
  assertEquals(facts, { userId: PATIENT_A, isPatient: true, staffRole: null, isPlatformAdmin: false })
})

Deno.test('intelligence caller facts: clinic patient record (patients.id = auth user)', async () => {
  const facts = await loadIntelligenceCallerFacts(fakeAdmin({ patients: { id: PATIENT_A } }), PATIENT_A)
  assertEquals(facts.isPatient, true)
})

Deno.test('intelligence caller facts: org member role and platform admin are read', async () => {
  const facts = await loadIntelligenceCallerFacts(
    fakeAdmin({ org_members: { role: 'physician' }, platform_admins: { user_id: PATIENT_A } }),
    PATIENT_A,
  )
  assertEquals(facts, { userId: PATIENT_A, isPatient: false, staffRole: 'physician', isPlatformAdmin: true })
})

Deno.test('intelligence caller facts: a lookup error throws (fail closed, never treated as a patient)', async () => {
  await assertRejects(() =>
    loadIntelligenceCallerFacts(fakeAdmin({ patient_self_signups: { user_id: PATIENT_A } }, 'org_members'), PATIENT_A),
  )
})
