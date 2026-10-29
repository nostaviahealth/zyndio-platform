import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { classifyIntelligenceCaller } from '../_shared/intelligenceCaller.ts'
import { AuthError, requireAuthenticatedActor } from '../_shared/requireOrgAdminActor.ts'
import { decideIntelligenceAccess, loadIntelligenceCallerFacts } from '../_shared/intelligenceAccess.ts'

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
 * Expected request body:
 * {
 *   "messages": [...],           // OpenAI chat messages
 *   "stream": boolean,           // Whether to stream the response
 *   "max_completion_tokens": number,
 *   "response_format": object,   // Optional (e.g. { "type": "json_object" })
 *   "tools": [...],              // Optional tool definitions
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

        // Read request body
        const body = await req.json()

        // ...and only on their own data: a request that names a patient must
        // name the caller.
        const dataAccess = decideIntelligenceAccess(facts, body?.patient_id)
        if (!dataAccess.ok) {
            return new Response(
                JSON.stringify({ error: dataAccess.error }),
                { status: dataAccess.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        const {
            messages,
            stream = false,
            max_completion_tokens = 4096,
            response_format,
            tools,
            tool_choice,
        } = body

        if (!messages || !Array.isArray(messages)) {
            return new Response(
                JSON.stringify({ error: 'messages array is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
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

        console.log(`Final Gemini API URL: ${openaiUrl}`)

        // Build the request body for OpenAI
        const openaiBody: Record<string, unknown> = {
            model: "gemini-3.5-flash",
            messages,
            max_tokens: max_completion_tokens,
        }

        if (stream) openaiBody.stream = true
        if (response_format) openaiBody.response_format = response_format
        if (tools && tools.length > 0) {
            openaiBody.tools = tools
            openaiBody.tool_choice = tool_choice ?? "auto"
        }

        console.log(`Calling Gemini OpenAI API: ${openaiUrl}`)

        // Call the Gemini API
        const openaiResponse = await fetch(openaiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`,
            },
            body: JSON.stringify(openaiBody),
        })

        if (!openaiResponse.ok) {
            const errorText = await openaiResponse.text()
            console.error(`OpenAI API Error: ${openaiResponse.status} - ${errorText}`)
            
            // Return a more descriptive error to help debugging
            let errorMessage = `AI service error: ${openaiResponse.status}`;
            try {
                const errorJson = JSON.parse(errorText);
                if (errorJson.error?.message) {
                    errorMessage = errorJson.error.message;
                }
            } catch (e) {
                // If not JSON, use raw text or generic status
                if (errorText.length < 100) errorMessage += ` - ${errorText}`;
            }

            return new Response(
                JSON.stringify({ error: errorMessage, details: errorText }),
                { status: openaiResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
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
        console.log(`Azure OpenAI Response Status: ${openaiResponse.status}`)
        return new Response(
            JSON.stringify(data),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Edge Function Error:', error)
        return new Response(
            // TC-021 #9: the caught value is `unknown` (TS18046) - narrow it.
            JSON.stringify({ error: error instanceof Error ? error.message : 'internal error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
