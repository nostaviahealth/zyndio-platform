import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.118.0"
import { isAuthorizedRevenueCatRequest } from "../_shared/revenueCatWebhookAuth.ts"
import { decideRevenueCatEvent } from "../_shared/revenueCatEvent.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WebhookDeps {
  env: { get(key: string): string | undefined }
  createServiceClient: () => SupabaseClient
  now?: () => number
}

const defaultDeps: WebhookDeps = {
  env: Deno.env,
  createServiceClient: () =>
    createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''),
}

// Postgres errors that will never succeed on retry: the app_user_id is not a
// patient (FK) or not a valid value. Acknowledge them so RevenueCat stops
// retrying, and log for follow-up.
const PERMANENT_DB_ERRORS = new Set(['23503', '22P02'])

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  })
}

// TC-026: RevenueCat sends a shared secret in the Authorization header
// (configured in the RevenueCat dashboard), checked here before anything
// else - missing/wrong secret or an unset REVENUECAT_WEBHOOK_AUTH env var
// (fail closed) is rejected with 401 before the body is parsed or the
// database is touched.
//
// The premium decision (_shared/revenueCatEvent.ts) is applied by
// public.apply_revenuecat_event, which records the event id (duplicates are
// no-ops) and only writes if the event is newer than the last one applied
// (out-of-order deliveries cannot downgrade a renewed patient). It upserts
// patient_accounts, so a purchase for a patient with no row yet creates it
// (TC-030 item 2). A transient failure - DB error or a crash - returns 5xx so
// RevenueCat retries; replays are safe because of the event-id check.
export async function handleRevenueCatWebhook(req: Request, deps: WebhookDeps = defaultDeps): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const expectedSecret = deps.env.get('REVENUECAT_WEBHOOK_AUTH')
  if (!isAuthorizedRevenueCatRequest(req.headers.get('Authorization'), expectedSecret)) {
    return json({ error: 'unauthorized' }, 401)
  }

  let payload: unknown
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'invalid_json' }, 400)
  }

  try {
    const decision = decideRevenueCatEvent(payload, (deps.now ?? Date.now)())
    if (decision.kind === 'ignore') {
      console.warn('handle-revenuecat-webhook: ignored event', decision.reason)
      // 200: acknowledged, nothing for us to do; retrying would not change it.
      return json({ ignored: decision.reason }, 200)
    }

    const supabaseClient = deps.createServiceClient()
    const { data, error } = await supabaseClient.rpc('apply_revenuecat_event', {
      p_event_id: decision.eventId,
      p_patient_id: decision.patientId,
      p_event_type: decision.eventType,
      p_event_at: decision.eventAt,
      p_action: decision.action,
      p_expires_at: decision.expiresAt,
    })

    if (error) {
      const code = (error as { code?: string }).code ?? ''
      if (PERMANENT_DB_ERRORS.has(code)) {
        console.warn('handle-revenuecat-webhook: event for unknown patient ignored', code)
        return json({ ignored: 'unknown_patient' }, 200)
      }
      console.error('handle-revenuecat-webhook: apply failed', code || 'unknown')
      return json({ error: 'internal_error' }, 500)
    }

    return json({ message: 'Success', outcome: data }, 200)
  } catch (error) {
    // Never echo internal error details; 5xx so RevenueCat retries.
    console.error('handle-revenuecat-webhook: processing crashed', error instanceof Error ? error.name : 'unknown')
    return json({ error: 'internal_error' }, 500)
  }
}

// Guarded so importing this module for tests doesn't try to bind a real
// network listener (deno test runs without --allow-net).
if (import.meta.main) {
  serve((req) => handleRevenueCatWebhook(req))
}
