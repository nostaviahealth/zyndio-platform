// INT-02 webhook delivery worker entrypoint. service_role only (same bearer
// check as process-outbox); invoked every minute by pg_cron through pg_net
// (_cron_kick_webhook_worker, 20261104150200) whenever a delivery is due.
// WEBHOOKS_ALLOW_LOCAL_RECEIVERS=true lets local dev deliver to
// http://127.0.0.1 / localhost; never set it in a deployed environment.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { parseBearerToken, verifyBearerJwt } from '../_shared/validation.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { deliverDue } from './worker.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const token = parseBearerToken(req.headers.get('Authorization'))
    if (!token) return jsonResponse(req, { error: 'missing bearer token' }, 401)

    let payload: Record<string, unknown>
    try {
      payload = await verifyBearerJwt(token, Deno.env)
    } catch {
      return jsonResponse(req, { error: 'invalid token' }, 401)
    }
    if (payload.role !== 'service_role') {
      return jsonResponse(req, { error: 'service_role required' }, 403)
    }

    const admin = serviceRoleClient()
    const result = await deliverDue({
      rpc: (fn, args) => admin.rpc(fn, args),
      fetch: (url, init) => fetch(url, init),
      nowMs: () => Date.now(),
      timeoutMs: 10_000,
      allowLocalReceivers: Deno.env.get('WEBHOOKS_ALLOW_LOCAL_RECEIVERS') === 'true',
      log: (message, detail) => console.error(message, detail ?? ''),
    })
    return jsonResponse(req, { status: 'ok', ...result })
  } catch (err) {
    console.error('deliver-webhooks error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
