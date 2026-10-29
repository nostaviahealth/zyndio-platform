// TC-021 item 23: read the intelligence request body without leaking parser
// text. Anything that is not a JSON object (invalid JSON, an empty body,
// `null`, an array or a scalar) is a generic 400 for the caller.
export const INVALID_BODY_ERROR = 'invalid request body'

// The body was `any` (from req.json()) before item 23; keep that type for the
// existing field handling in intelligence/index.ts.
// deno-lint-ignore no-explicit-any
type IntelligenceBody = Record<string, any>

export async function readIntelligenceBody(
  req: Request,
): Promise<{ ok: true; body: IntelligenceBody } | { ok: false }> {
  let parsed: unknown
  try {
    parsed = JSON.parse(await req.text())
  } catch {
    return { ok: false }
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return { ok: false }
  }
  return { ok: true, body: parsed as IntelligenceBody }
}
