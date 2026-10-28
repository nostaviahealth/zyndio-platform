export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// One shape for every "don't reveal account/invite/user existence" error -
// callers can't distinguish "not found" from "not allowed" from the body.
export function genericErrorResponse(status = 400): Response {
  return jsonResponse({ error: 'request_could_not_be_completed' }, status)
}
