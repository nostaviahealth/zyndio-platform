// APP-01: open patient self-sign-up is off unless the org turns it on
// (organizations.patient_self_signup_enabled). The patient app is built for
// one clinic org, named by ZYNDIO_DEFAULT_ORG_ID (already required by
// patient-request-link-code). No org configured, an unknown org, or any
// lookup error all read as closed.
import { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { isValidUuid } from './validation.ts'

export async function isSelfSignupOpen(
  admin: Pick<SupabaseClient, 'rpc'>,
  env: { get(key: string): string | undefined },
): Promise<boolean> {
  const orgId = env.get('ZYNDIO_DEFAULT_ORG_ID')?.trim() ?? ''
  if (!isValidUuid(orgId)) return false
  const { data, error } = await admin.rpc('patient_self_signup_open', { p_org_id: orgId })
  if (error) {
    console.error('isSelfSignupOpen: patient_self_signup_open failed', { code: (error as { code?: string }).code })
    return false
  }
  return data === true
}
