// Clause 9.2. Feature identity is the route the request hit, never a field
// in the JSON body. A missing switch row does not enable a feature: the
// production default is an open decision, and this candidate fails closed
// unless an explicit enabled row exists. A lookup error throws so the caller
// returns 503 and does not call a model.

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'

export const AI_FEATURES = ['companion', 'food_analysis', 'lab_extraction', 'coaching', 'memory'] as const
export type AiFeature = typeof AI_FEATURES[number]

export const AI_FEATURE_DISABLED_ERROR = 'ai_feature_disabled'

export interface AiFeatureSwitchRow {
  org_id: string | null
  feature: string
  enabled: boolean
}

const PATH_FEATURES: Record<string, AiFeature> = {
  companion: 'companion',
  'food-analysis': 'food_analysis',
  'lab-extraction': 'lab_extraction',
  coaching: 'coaching',
  memory: 'memory',
}

/** The bare `/intelligence` URL is the companion route. Any other suffix must match a known feature. */
export function featureFromIntelligencePath(pathname: string): AiFeature | null {
  const match = pathname.match(/\/intelligence(?:\/([a-z0-9-]+))?\/?$/)
  if (!match) return null
  const slug = match[1]
  if (!slug) return 'companion'
  return PATH_FEATURES[slug] ?? null
}

export function isAiFeatureEnabled(
  rows: AiFeatureSwitchRow[],
  orgId: string | null,
  feature: AiFeature,
): boolean {
  const specific = rows.find((r) => r.org_id === orgId && r.feature === feature)
    ?? rows.find((r) => r.org_id === null && r.feature === feature)
  if (!specific || !specific.enabled) return false
  const wildcard = rows.find((r) => r.org_id === orgId && r.feature === '*')
    ?? rows.find((r) => r.org_id === null && r.feature === '*')
  if (wildcard && !wildcard.enabled) return false
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

export async function aiFeatureAllowed(
  admin: SupabaseClient,
  userId: string,
  feature: AiFeature,
): Promise<boolean> {
  const { orgId, rows } = await loadAiFeatureSwitches(admin, userId)
  return isAiFeatureEnabled(rows, orgId, feature)
}
