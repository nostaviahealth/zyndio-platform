import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.118.0"
import { isAuthorizedRevenueCatRequest } from "../_shared/revenueCatWebhookAuth.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WebhookDeps {
  env: { get(key: string): string | undefined }
  createServiceClient: () => SupabaseClient
}

const defaultDeps: WebhookDeps = {
  env: Deno.env,
  createServiceClient: () =>
    createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''),
}

// TC-026: RevenueCat sends a shared secret in the Authorization header
// (configured in the RevenueCat dashboard), checked here before anything
// else - missing/wrong secret or an unset REVENUECAT_WEBHOOK_AUTH env var
// (fail closed) is rejected with 401 before the body is parsed or the
// database is touched. Writes go to patient_accounts (service role; the
// column-level revoke on is_premium/subscription_plan only applies to
// authenticated/anon, not service_role) instead of the removed `profiles`
// table - app_user_id is the patient's auth uid, which is patient_accounts'
// primary key directly, no profile-id lookup needed.
//
// TC-030 item 2 (Clara PR #25 M2): the write is an UPSERT on patient_id, not a
// bare UPDATE, so a purchase for a patient who has no patient_accounts row yet
// creates the row instead of silently writing 0 rows and returning 200. A real
// DB error returns 500 so RevenueCat retries; replaying the same event is
// idempotent (same end state, no error).
export async function handleRevenueCatWebhook(req: Request, deps: WebhookDeps = defaultDeps): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const expectedSecret = deps.env.get('REVENUECAT_WEBHOOK_AUTH')
  if (!isAuthorizedRevenueCatRequest(req.headers.get('Authorization'), expectedSecret)) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 401,
    })
  }

  try {
    const supabaseClient = deps.createServiceClient()

    const payload = await req.json()

    // Support both 'event' wrapper (v1) and flat object (v2) formats
    const event = payload.event || payload
    const { app_user_id, entitlement_ids, type } = event

    if (!app_user_id) {
      return new Response(JSON.stringify({ error: 'no_app_user_id' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Return 200 to acknowledge receipt even if invalid for us
      })
    }

    let subscriptionPlan = 'free'
    let isPremium = false

    // Check if user has 'Zyndio Plus' entitlement
    if (entitlement_ids && entitlement_ids.includes('Zyndio Plus')) {
      subscriptionPlan = 'plus'
      isPremium = true
    }

    // Handle expiration/cancellation specifically if needed
    if (type === 'EXPIRATION' || type === 'CANCELLATION') {
      if (!entitlement_ids || entitlement_ids.length === 0) {
        subscriptionPlan = 'free'
        isPremium = false
      }
    }

    // TC-030 item 2 (Clara PR #25 M2): the old `.update().eq()` wrote 0 rows and
    // still returned 200 "Success" when the patient had no patient_accounts row
    // yet (the row only appears after a later client write), so RevenueCat never
    // retried and the purchase was lost. Upsert on patient_id (the primary key)
    // instead: it creates the row if missing and overwrites it if present, so a
    // premium INITIAL_PURCHASE lands immediately and the operation is idempotent
    // - replaying the same event converges on the same is_premium/plan with no
    // error. Columns not named default on INSERT (xp/coins/league 0, name null,
    // etc.) and are untouched on UPDATE. service_role bypasses the authenticated
    // column revokes on is_premium/subscription_plan.
    const { error: upsertError } = await supabaseClient
      .from('patient_accounts')
      .upsert(
        {
          patient_id: app_user_id,
          subscription_plan: subscriptionPlan,
          is_premium: isPremium,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'patient_id' },
      )

    if (upsertError) {
      // A real write failure (not a known no-op edge case): return a 5xx so
      // RevenueCat retries instead of dropping the purchase silently.
      console.error('handle-revenuecat-webhook: database upsert failed', upsertError)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    return new Response(JSON.stringify({ message: 'Success' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('handle-revenuecat-webhook: processing crashed', error instanceof Error ? error.message : error)
    // Never echo internal error details to the caller.
    return new Response(JSON.stringify({ error: 'internal_error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  }
}

// Guarded so importing this module for tests doesn't try to bind a real
// network listener (deno test runs without --allow-net).
if (import.meta.main) {
  serve((req) => handleRevenueCatWebhook(req))
}
