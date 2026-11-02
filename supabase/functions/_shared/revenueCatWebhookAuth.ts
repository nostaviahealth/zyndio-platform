// TC-026: RevenueCat sends a shared secret in the Authorization header
// (configured in the RevenueCat dashboard, not a signed JWT), so this checks
// it against REVENUECAT_WEBHOOK_AUTH rather than going through the bearer-JWT
// verification in validation.ts. Pure/dependency-free so it's trivially unit
// testable without touching the network or the database - the index.ts
// handler is responsible for reading the env var and the request header and
// rejecting (401, before any DB call) on a `false` result here.
import { constantTimeEqual } from './validation.ts'

export function isAuthorizedRevenueCatRequest(
  authHeader: string | null | undefined,
  expectedSecret: string | null | undefined
): boolean {
  if (!expectedSecret) return false // fail closed: unset/empty env var never authorizes
  if (!authHeader) return false
  return constantTimeEqual(authHeader, expectedSecret)
}
