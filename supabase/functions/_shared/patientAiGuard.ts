// Front door for patient AI Edge Functions that aren't the main intelligence
// proxy (embed-memory, search-memory). Same checks as intelligence, in the
// same order: a user JWT (not the anon key), a GoTrue-verified session, a
// patient acting on their own data only, then the per-feature kill switch.
// Before this, both memory functions trusted a user_id from the body and used
// the service role, so any holder of the public anon key could read or write
// any patient's memories.

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { classifyIntelligenceCaller } from './intelligenceCaller.ts'
import { AuthError, requireAuthenticatedActor } from './requireOrgAdminActor.ts'
import { decideIntelligenceAccess, loadIntelligenceCallerFacts } from './intelligenceAccess.ts'
import { AI_FEATURE_DISABLED_ERROR, type AiFeature, aiFeatureAllowed } from './aiFeatureSwitch.ts'

export type PatientAiGuard =
  | { ok: true; userId: string; admin: SupabaseClient }
  | { ok: false; status: number; body: Record<string, unknown> }

export async function guardPatientAiRequest(
  req: Request,
  requestedPatientId: unknown,
  feature: AiFeature,
): Promise<PatientAiGuard> {
  const caller = classifyIntelligenceCaller(req.headers.get('Authorization'))
  if (!caller.ok) return { ok: false, status: caller.status, body: { error: caller.error } }

  let actor: { userId: string; admin: SupabaseClient }
  try {
    actor = await requireAuthenticatedActor(req)
  } catch (err) {
    if (err instanceof AuthError) return { ok: false, status: err.status, body: { error: 'invalid session' } }
    throw err
  }

  let access
  try {
    access = decideIntelligenceAccess(await loadIntelligenceCallerFacts(actor.admin, actor.userId), requestedPatientId)
  } catch {
    return { ok: false, status: 503, body: { error: 'access check unavailable' } }
  }
  if (!access.ok) return { ok: false, status: access.status, body: { error: access.error } }

  let allowed: boolean
  try {
    allowed = await aiFeatureAllowed(actor.admin, actor.userId, feature)
  } catch {
    return { ok: false, status: 503, body: { error: 'ai switch check unavailable' } }
  }
  if (!allowed) return { ok: false, status: 503, body: { error: AI_FEATURE_DISABLED_ERROR, feature } }

  return { ok: true, userId: actor.userId, admin: actor.admin }
}
