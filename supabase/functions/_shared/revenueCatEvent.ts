// Turns a RevenueCat webhook event into the one premium decision we store.
//
// RevenueCat semantics (https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields):
//   * EXPIRATION - access has ended. Its entitlement_ids still list the
//     entitlement that expired, so "has the entitlement" must NOT mean premium
//     here (the old code kept expired patients premium).
//   * CANCELLATION - auto-renew turned off (or a refund). Access continues
//     until expiration_at_ms; for a refund that time is already past.
//   * BILLING_ISSUE / SUBSCRIPTION_PAUSED - access continues until expiry.
//   * TEST / TRANSFER / anything without our patient id - acknowledged, no change.
// So: grant while the entitlement is present and not yet expired; otherwise
// revoke. Ordering and duplicates are handled in Postgres
// (public.apply_revenuecat_event) using the event id and event timestamp.

export const PREMIUM_ENTITLEMENT = 'Zyndio Plus'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export type RevenueCatDecision =
  | {
      kind: 'apply'
      eventId: string
      patientId: string
      eventType: string
      eventAt: string
      action: 'grant' | 'revoke'
      expiresAt: string | null
    }
  | { kind: 'ignore'; reason: string }

function msToIso(v: unknown): string | null {
  const n = typeof v === 'number' ? v : typeof v === 'string' && v.trim() !== '' ? Number(v) : NaN
  if (!Number.isFinite(n) || n <= 0) return null
  const d = new Date(n)
  return Number.isNaN(d.getTime()) ? null : d.toISOString()
}

export function decideRevenueCatEvent(payload: unknown, nowMs: number = Date.now()): RevenueCatDecision {
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
    return { kind: 'ignore', reason: 'not_an_object' }
  }
  const wrapper = payload as Record<string, unknown>
  // Support both the 'event' wrapper and a flat object.
  const event = (wrapper.event && typeof wrapper.event === 'object' ? wrapper.event : wrapper) as Record<string, unknown>

  const type = typeof event.type === 'string' ? event.type : ''
  if (type === '' ) return { kind: 'ignore', reason: 'no_type' }
  if (type === 'TEST') return { kind: 'ignore', reason: 'test_event' }
  if (type === 'TRANSFER') return { kind: 'ignore', reason: 'transfer_unsupported' }

  const patientId = typeof event.app_user_id === 'string' ? event.app_user_id : ''
  if (!patientId) return { kind: 'ignore', reason: 'no_app_user_id' }
  // Anonymous RevenueCat ids are not our patients; nor is anything not a UUID.
  if (!UUID.test(patientId)) return { kind: 'ignore', reason: 'app_user_id_not_a_patient' }

  const eventId = typeof event.id === 'string' ? event.id.trim() : ''
  if (!eventId || eventId.length > 200) return { kind: 'ignore', reason: 'no_event_id' }

  const eventAt = msToIso(event.event_timestamp_ms)
  if (!eventAt) return { kind: 'ignore', reason: 'no_event_timestamp' }

  const expiresAt = msToIso(event.expiration_at_ms)
  const entitlements = Array.isArray(event.entitlement_ids) ? event.entitlement_ids : []
  const hasEntitlement = entitlements.includes(PREMIUM_ENTITLEMENT)
  const notExpired = expiresAt === null || Date.parse(expiresAt) > nowMs

  const action: 'grant' | 'revoke' = type !== 'EXPIRATION' && hasEntitlement && notExpired ? 'grant' : 'revoke'

  return { kind: 'apply', eventId, patientId: patientId.toLowerCase(), eventType: type, eventAt, action, expiresAt }
}
