import { decodeJwtPayload, parseBearerToken } from './validation.ts'

// TC-022 #4: who may call the intelligence function, decided BEFORE the
// request body is read or validated, so a wrong-role caller gets 403 and
// learns nothing about the body shape (and never reaches the AI provider).
//
// Only a signed-in user's access token (JWT role claim "authenticated") is
// accepted. The bare anon/publishable key and the service-role key are not
// a user, so they get 403. This only reads the claim; the function then
// verifies the token itself with GoTrue (requireAuthenticatedActor).
export type IntelligenceCaller =
  | { ok: true; token: string }
  | { ok: false; status: 401 | 403; error: string }

export function classifyIntelligenceCaller(authorizationHeader: string | null | undefined): IntelligenceCaller {
  const token = parseBearerToken(authorizationHeader)
  if (!token) return { ok: false, status: 401, error: 'Missing authorization header' }

  let role: unknown
  try {
    role = decodeJwtPayload(token).role
  } catch {
    role = undefined // not a JWT, e.g. an sb_publishable_/sb_secret_ key
  }
  if (role !== 'authenticated') return { ok: false, status: 403, error: 'forbidden' }

  return { ok: true, token }
}
