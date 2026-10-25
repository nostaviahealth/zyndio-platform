import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload = await req.json()
    console.log('Received RevenueCat Payload:', JSON.stringify(payload, null, 2))

    // Support both 'event' wrapper (v1) and flat object (v2) formats
    const event = payload.event || payload
    const { type, app_user_id, entitlement_ids } = event

    if (!app_user_id) {
      console.error('No app_user_id found in RevenueCat event')
      return new Response(JSON.stringify({ error: 'No app_user_id' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // Return 200 to acknowledge receipt even if invalid for us
      })
    }

    console.log(`Processing event ${type} for user ${app_user_id}`)

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

    // CRITICAL: We match on 'user_id' (Auth UUID) instead of 'id' (Profile PK)
    const { data: profile, error: fetchError } = await supabaseClient
      .from('profiles')
      .select('id, user_id')
      .eq('user_id', app_user_id)
      .maybeSingle()

    if (fetchError) {
      console.error('Error fetching profile for user_id:', app_user_id, fetchError)
      throw fetchError
    }

    if (!profile) {
      console.warn(`No profile found for Supabase Auth UID: ${app_user_id}. Attempting fallback...`)
      // If we can't find them, we don't error out with a 400 (which triggers RC retries)
      // but we do log it so we can investigate identity mismatch.
      return new Response(JSON.stringify({ message: 'User profile not found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const { error: updateError } = await supabaseClient
      .from('profiles')
      .update({ 
        subscription_plan: subscriptionPlan,
        is_premium: isPremium,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', app_user_id) // Again, use user_id for accuracy

    if (updateError) {
      console.error('Database update failed:', updateError)
      throw updateError
    }

    console.log(`✅ Success: Updated user ${app_user_id} status to ${subscriptionPlan}`)

    return new Response(JSON.stringify({ message: 'Success' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('🔴 Webhook Processing CRASHED:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200, // Return 200 to RevenueCat to avoid persistent retries on known edge cases
    })
  }
})
