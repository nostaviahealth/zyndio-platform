// TC-011 L11: `*` let any origin call these functions cross-site (the bearer
// token in the request is what actually gates access, but a wildcard ACAO
// still needlessly widens the attack surface - e.g. a malicious page could
// read the JSON error body of an unauthenticated probe). Reflect the
// request's Origin only when it matches a known admin origin; otherwise omit
// Access-Control-Allow-Origin entirely so the browser blocks the response.
//
// Local admin dev servers (root Vite admin app + `space/`) plus whatever the
// deployed admin origin is, via ADMIN_ORIGIN or SITE_URL. Production must set
// ADMIN_ORIGIN (or SITE_URL) to the real admin origin - without it, only the
// local dev origins below are ever allowed.
const LOCAL_ADMIN_ORIGINS = [
  'http://127.0.0.1:5173',
  'http://localhost:5173',
  'http://127.0.0.1:3100',
  'http://localhost:3100',
]

// `deno test` for this module runs with no --allow-env (see
// .github/workflows/ci.yml), so env access must degrade gracefully rather
// than crash the whole suite - the deployed Edge Function runtime always
// grants env access, this only matters for the unit tests.
function readEnv(name: string): string | undefined {
  try {
    return Deno.env.get(name)
  } catch {
    return undefined
  }
}

function allowedOrigins(): string[] {
  const configured = [readEnv('ADMIN_ORIGIN'), readEnv('SITE_URL')].filter((v): v is string => !!v)
  return [...LOCAL_ADMIN_ORIGINS, ...configured]
}

export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get('origin')
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    Vary: 'Origin',
  }
  if (origin && allowedOrigins().includes(origin)) {
    headers['Access-Control-Allow-Origin'] = origin
  }
  return headers
}

export function jsonResponse(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(req), 'Content-Type': 'application/json' },
  })
}

// One shape for every "don't reveal account/invite/user existence" error -
// callers can't distinguish "not found" from "not allowed" from the body.
export function genericErrorResponse(req: Request, status = 400): Response {
  return jsonResponse(req, { error: 'request_could_not_be_completed' }, status)
}
