import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { classifyIntelligenceCaller } from '../_shared/intelligenceCaller.ts'
import { AuthError, requireAuthenticatedActor } from '../_shared/requireOrgAdminActor.ts'
import { decideIntelligenceAccess, loadIntelligenceCallerFacts } from '../_shared/intelligenceAccess.ts'
import { consumeIntelligenceBudget, rateLimitedHeaders } from '../_shared/intelligenceRateLimit.ts'
import { INVALID_BODY_ERROR, readIntelligenceBody } from '../_shared/intelligenceBody.ts'
import { AI_FEATURE_DISABLED_ERROR, aiFeatureAllowed, normaliseAiFeature } from '../_shared/aiFeatureSwitch.ts'
import { buildProviderRequest, providerFailure } from '../_shared/intelligenceProviderRequest.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Supabase Edge Function: intelligence
 * 
 * A secure proxy for OpenAI API calls. All AI keys are stored as Supabase
 * secrets and never exposed to the client. Supports both streaming and
 * non-streaming completions.
 * 
 * Expected request body (validated and rebuilt by
 * _shared/intelligenceProviderRequest.ts - nothing else is forwarded):
 * {
 *   "messages": [...],           // OpenAI chat messages (bounded; images from the user only)
 *   "stream": boolean,           // Whether to stream the response
 *   "max_completion_tokens": number, // capped at 16384
 *   "response_format": object,   // Optional: { "type": "json_object" | "text" }
 *   "tools": [...],              // Optional function tool definitions
 *   "tool_choice": string,       // Optional tool choice
 *   "patient_id": string,        // Optional; if given it must be the caller (TC-021 #9)
 * }
 */
serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // TC-022 #4: check the caller's role before reading or validating the
        // body - wrong role is 403, never a 400 about the body.
        const caller = classifyIntelligenceCaller(req.headers.get('Authorization'))
        if (!caller.ok) {
            return new Response(
                JSON.stringify({ error: caller.error }),
                { status: caller.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        // Then verify the user token with GoTrue itself (expired/forged -> 401).
        let actor: Awaited<ReturnType<typeof requireAuthenticatedActor>>
        try {
            actor = await requireAuthenticatedActor(req)
        } catch (err) {
            if (err instanceof AuthError) {
                return new Response(
                    JSON.stringify({ error: 'invalid session' }),
                    { status: err.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
            throw err
        }

        // TC-021 #9: patients only - every staff role, the Zyndio admin and
        // any non-patient get 403 here, still before the body is read.
        let facts: Awaited<ReturnType<typeof loadIntelligenceCallerFacts>>
        try {
            facts = await loadIntelligenceCallerFacts(actor.admin, actor.userId)
        } catch (err) {
            console.error('intelligence: access lookup failed', err instanceof Error ? err.message : 'unknown')
            return new Response(
                JSON.stringify({ error: 'access check unavailable' }),
                { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        const callerAccess = decideIntelligenceAccess(facts, undefined)
        if (!callerAccess.ok) {
            return new Response(
                JSON.stringify({ error: callerAccess.error }),
                { status: callerAccess.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Read request body. TC-021 item 23: invalid JSON, an empty body or a
        // non-object (e.g. `null`) is a generic 400 - never a 500 and never the
        // parser's own text. Still after the auth and role checks above.
        const parsed = await readIntelligenceBody(req)
        if (!parsed.ok) {
            return new Response(
                JSON.stringify({ error: INVALID_BODY_ERROR }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        const body = parsed.body

        // ...and only on their own data: a request that names a patient must
        // name the caller.
        const dataAccess = decideIntelligenceAccess(facts, body?.patient_id)
        if (!dataAccess.ok) {
            return new Response(
                JSON.stringify({ error: dataAccess.error }),
                { status: dataAccess.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        // PRD clause 9.2: per-feature kill switch, before any provider call.
        // Unlabelled requests count as 'companion'. Fail closed if unreadable.
        const feature = normaliseAiFeature(body?.feature)
        let featureAllowed: boolean
        try {
            featureAllowed = await aiFeatureAllowed(actor.admin, actor.userId, feature)
        } catch (err) {
            console.error('intelligence: ai switch check failed', err instanceof Error ? err.message : 'unknown')
            return new Response(
                JSON.stringify({ error: 'ai switch check unavailable' }),
                { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        if (!featureAllowed) {
            return new Response(
                JSON.stringify({ error: AI_FEATURE_DISABLED_ERROR, feature }),
                { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Allowlist the provider request (model pinned, token ceiling, bounded
        // messages/images/tools) before spending any budget.
        const providerRequest = buildProviderRequest(body)
        if (!providerRequest.ok) {
            return new Response(
                JSON.stringify({ error: providerRequest.error }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        const stream = providerRequest.stream

        // TC-021 #12: per-patient budget (hour + day), checked before any
        // provider call. Over budget -> 429 + Retry-After. If the counter
        // cannot be read we fail closed (503) rather than call unmetered.
        let budget
        try {
            budget = await consumeIntelligenceBudget(actor.admin, actor.userId)
        } catch (err) {
            console.error('intelligence rate limit check failed:', err instanceof Error ? err.message : 'unknown error')
            return new Response(
                JSON.stringify({ error: 'rate limit check unavailable' }),
                { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        if (!budget.allowed) {
            return new Response(
                JSON.stringify({ error: 'rate_limited', retry_after_seconds: budget.retryAfterSeconds }),
                { status: 429, headers: { ...corsHeaders, ...rateLimitedHeaders(budget.retryAfterSeconds), 'Content-Type': 'application/json' } }
            )
        }

        // Use Gemini's OpenAI-compatible API
        const apiKey = Deno.env.get('GEMINI_API_KEY') ?? ''

        if (!apiKey) {
            console.error('Missing GEMINI_API_KEY secret')
            return new Response(
                JSON.stringify({ error: 'AI service not configured' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const openaiUrl = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"

        // Call the Gemini API
        const openaiResponse = await fetch(openaiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`,
            },
            body: JSON.stringify(providerRequest.body),
        })

        if (!openaiResponse.ok) {
            // Log the status only: the provider body can echo patient content.
            // The caller gets our own code and status, never provider text.
            await openaiResponse.body?.cancel()
            console.error(`intelligence: provider error ${openaiResponse.status}`)
            const failure = providerFailure(openaiResponse.status)
            return new Response(
                JSON.stringify(failure.body),
                { status: failure.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // --- STREAMING MODE ---
        if (stream) {
            // Pipe the SSE stream directly from OpenAI to the client
            return new Response(openaiResponse.body, {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive',
                },
            })
        }

        // --- NON-STREAMING MODE ---
        const data = await openaiResponse.json()
        return new Response(
            JSON.stringify(data),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('intelligence: failed', error instanceof Error ? error.name : 'unknown')
        return new Response(
            // Never the exception text: it can carry provider or DB detail.
            JSON.stringify({ error: 'internal error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
