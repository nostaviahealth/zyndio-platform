// PRD clause 9.2: per-feature AI kill switch (public.ai_feature_switches).
// The app labels each AI request with the feature it serves; a request with no
// or an unknown label counts as 'companion', the most sensitive one, so an
// unlabelled call can't slip past a switched-off companion.
//
// A switch row applies to one clinic (org_id) or to every clinic (org_id
// null); feature '*' covers every AI feature. No row means on. Lookups go
// through the service-role client and throw on error: callers answer 503 and
// never call the model when the switch can't be read.

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'

export const AI_FEATURES = ['companion', 'food_analysis', 'lab_extraction', 'coaching', 'memory'] as const
export type AiFeature = typeof AI_FEATURES[number]

export const AI_FEATURE_DISABLED_ERROR = 'ai_feature_disabled'

export interface AiFeatureSwitchRow {
  org_id: string | null
  feature: string
  enabled: boolean
}

export function normaliseAiFeature(value: unknown): AiFeature {
  return (AI_FEATURES as readonly unknown[]).includes(value) ? value as AiFeature : 'companion'
}

// A clinic's own row wins over the all-clinics row for the same feature; any
// applicable "off" for the feature or for '*' switches the feature off.
export function isAiFeatureEnabled(
  rows: AiFeatureSwitchRow[],
  orgId: string | null,
  feature: AiFeature,
): boolean {
  for (const scope of [feature, '*']) {
    const own = orgId === null ? undefined : rows.find((r) => r.org_id === orgId && r.feature === scope)
    const global = rows.find((r) => r.org_id === null && r.feature === scope)
    const effective = own ?? global
    if (effective && !effective.enabled) return false
  }
  return true
}

export async function loadAiFeatureSwitches(
  admin: SupabaseClient,
  userId: string,
): Promise<{ orgId: string | null; rows: AiFeatureSwitchRow[] }> {
  const { data: patient, error: patientError } = await admin
    .from('patients').select('org_id').eq('id', userId).maybeSingle()
  if (patientError) throw new Error('ai switch lookup failed: patients')
  const orgId = typeof patient?.org_id === 'string' ? patient.org_id : null

  let query = admin.from('ai_feature_switches').select('org_id, feature, enabled')
  query = orgId === null ? query.is('org_id', null) : query.or(`org_id.is.null,org_id.eq.${orgId}`)
  const { data, error } = await query
  if (error) throw new Error('ai switch lookup failed: ai_feature_switches')
  return { orgId, rows: (data ?? []) as AiFeatureSwitchRow[] }
}

// Convenience for the Edge Functions: true when the feature may run.
export async function aiFeatureAllowed(
  admin: SupabaseClient,
  userId: string,
  feature: AiFeature,
): Promise<boolean> {
  const { orgId, rows } = await loadAiFeatureSwitches(admin, userId)
  return isAiFeatureEnabled(rows, orgId, feature)
}
