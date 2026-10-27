// B5 / Henry ruling 3: the stub email worker. Real sending is TC-006; until
// then this is what "sends" every pending notification_outbox row - logs
// recipient + template (never the payload, never a token - L8), marks the
// row sent_stub, and nulls the plaintext invite token out of the stored
// payload now that it has "left the building". Modeled as an async worker
// (service_role only, meant to be invoked by a cron job once one exists)
// rather than running inline inside invite-user/deactivate-user/reset-mfa,
// TC-011: bearer JWT signature is verified here (HS256 + JWT_SECRET). The
// API gateway's JWT check must stay on in every deployed environment — this
// is defense in depth for direct function invocation.
// so the token is still readable by whatever actually delivers it right up
// until delivery - nulling it at insert time would make the invite
// permanently unusable by anyone, including a real mail provider.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { jwtSecretFromEnv, parseBearerToken, verifyHs256Jwt } from '../_shared/validation.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { sendNotificationStub } from '../_shared/emailStub.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const token = parseBearerToken(req.headers.get('Authorization'))
    if (!token) return jsonResponse({ error: 'missing bearer token' }, 401)

    let payload: Record<string, unknown>
    try {
      payload = await verifyHs256Jwt(token, jwtSecretFromEnv(Deno.env))
    } catch {
      return jsonResponse({ error: 'invalid token' }, 401)
    }
    if (payload.role !== 'service_role') {
      return jsonResponse({ error: 'service_role required' }, 403)
    }

    const admin = serviceRoleClient()
    const { data: pending, error: pendingError } = await admin
      .from('notification_outbox')
      .select('id, user_id, type, payload')
      .eq('status', 'pending')

    if (pendingError) {
      console.error('process-outbox: fetching pending rows failed', pendingError)
      return jsonResponse({ error: 'internal_error' }, 500)
    }

    let sent = 0
    for (const row of pending ?? []) {
      await sendNotificationStub(admin, {
        id: row.id,
        userId: row.user_id,
        type: row.type,
        payload: (row.payload ?? {}) as Record<string, unknown>,
      })
      sent++
    }

    return jsonResponse({ status: 'ok', sent })
  } catch (err) {
    console.error('process-outbox error', err)
    return jsonResponse({ error: 'internal_error' }, 500)
  }
})
