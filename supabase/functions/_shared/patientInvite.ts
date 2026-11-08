// APP-01: the one patient-invite path. create-patient (staff) calls it today;
// the integration API (POST /v1/patients) will call it with source 'api'.
//
// issue_patient_invite() (service_role only) records the invite, revoking any
// earlier open one, and returns the account email. The email itself is a
// notification_outbox row of type 'patient_invite' and carries no
// credential: it tells the patient to open the app and sign in with that
// email, which emails them a one-time code (patient-request-login-code).
import { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { insertNotification } from './auditAndNotify.ts'

export type PatientInviteSource = 'staff' | 'api'

export interface PatientInviteResult {
  inviteId: string
  orgId: string
  email: string
}

export class PatientInviteError extends Error {}

type Notify = typeof insertNotification

export function parseIssueInviteResult(data: unknown): PatientInviteResult | null {
  if (!data || typeof data !== 'object') return null
  const row = data as Record<string, unknown>
  if (typeof row.invite_id !== 'string' || typeof row.org_id !== 'string' || typeof row.email !== 'string') {
    return null
  }
  return { inviteId: row.invite_id, orgId: row.org_id, email: row.email }
}

export async function sendPatientInvite(
  admin: SupabaseClient,
  params: { patientId: string; invitedBy: string | null; source: PatientInviteSource },
  notify: Notify = insertNotification,
): Promise<PatientInviteResult> {
  const { data, error } = await admin.rpc('issue_patient_invite', {
    p_patient_id: params.patientId,
    p_invited_by: params.invitedBy,
    p_source: params.source,
  })
  const invite = parseIssueInviteResult(data)
  if (error || !invite) {
    throw new PatientInviteError('issue_patient_invite failed')
  }

  await notify(admin, {
    userId: params.patientId,
    orgId: invite.orgId,
    type: 'patient_invite',
    payload: { email: invite.email, invite_id: invite.inviteId },
  })

  return invite
}
