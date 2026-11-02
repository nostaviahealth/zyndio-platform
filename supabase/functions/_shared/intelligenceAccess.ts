// TC-021 item 9 (Henry ruling, 29 Oct): the intelligence function is for
// patients only, and only on their own data.
//
// - A patient is a signed-in user with a patient-app account
//   (public.patient_self_signups) or a clinic patient record whose id is the
//   auth user (public.patients.id).
// - Staff never get through, even if they also have a patient marker: any
//   public.org_members row (org_admin, physician, care_coordinator,
//   read_only - any status) or a public.platform_admins row (Zyndio admin)
//   is 403. There is no separate partner role in the schema; a partner
//   account is not a patient, so it is 403 by the same allow-list.
// - The request may name the patient it is about (body.patient_id). If it
//   does, it must be the caller; anything else is 403.
//
// Every lookup goes through the service-role client (none of these tables
// have client grants). A failed lookup throws - the caller answers 5xx and
// never treats an unknown caller as a patient.

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'

export interface IntelligenceCallerFacts {
  userId: string
  isPatient: boolean
  staffRole: string | null
  isPlatformAdmin: boolean
}

export type IntelligenceAccess =
  | { ok: true }
  | { ok: false; status: 403; error: 'intelligence_patients_only' | 'intelligence_own_data_only' }

export function decideIntelligenceAccess(
  facts: IntelligenceCallerFacts,
  requestedPatientId: unknown,
): IntelligenceAccess {
  if (facts.isPlatformAdmin || facts.staffRole !== null || !facts.isPatient) {
    return { ok: false, status: 403, error: 'intelligence_patients_only' }
  }
  if (requestedPatientId !== undefined && requestedPatientId !== null && requestedPatientId !== facts.userId) {
    return { ok: false, status: 403, error: 'intelligence_own_data_only' }
  }
  return { ok: true }
}

async function lookup(admin: SupabaseClient, table: string, columns: string, idColumn: string, userId: string) {
  const { data, error } = await admin.from(table).select(columns).eq(idColumn, userId).maybeSingle()
  if (error) throw new Error(`intelligence access lookup failed: ${table}`)
  return data as Record<string, unknown> | null
}

export async function loadIntelligenceCallerFacts(
  admin: SupabaseClient,
  userId: string,
): Promise<IntelligenceCallerFacts> {
  const [selfSignup, patientRecord, member, platformAdmin] = await Promise.all([
    lookup(admin, 'patient_self_signups', 'user_id', 'user_id', userId),
    lookup(admin, 'patients', 'id', 'id', userId),
    lookup(admin, 'org_members', 'role', 'user_id', userId),
    lookup(admin, 'platform_admins', 'user_id', 'user_id', userId),
  ])
  const role = member?.role
  return {
    userId,
    isPatient: selfSignup !== null || patientRecord !== null,
    staffRole: member === null ? null : typeof role === 'string' ? role : 'unknown',
    isPlatformAdmin: platformAdmin !== null,
  }
}
