import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { guardPatientAiRequest } from '../_shared/patientAiGuard.ts'
import { rateLimitedHeaders } from '../_shared/intelligenceRateLimit.ts'
import {
    consumeMemoryBudget,
    embeddingRequestBody,
    extractEmbedding,
    parseEmbedRequest,
} from '../_shared/memoryRequest.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, ...extra, 'Content-Type': 'application/json' },
    })
}

// Order: auth + own-data + kill switch (guard) -> input limits -> rate budget
// -> provider. Nothing reaches the embedding provider unmetered or oversized.
serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        let body: Record<string, unknown>
        try {
            const parsed = await req.json()
            body = parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {}
        } catch {
            body = {}
        }

        // Signed-in patient, own memories only, memory feature switched on.
        const guard = await guardPatientAiRequest(req, body.user_id, 'memory')
        if (!guard.ok) return json(guard.body, guard.status)

        if (!body.user_id) return json({ error: 'user_id and content are required' }, 400)
        const input = parseEmbedRequest(body)
        if (!input.ok) return json({ error: input.error }, 400)

        let budget
        try {
            budget = await consumeMemoryBudget(guard.admin, guard.userId)
        } catch {
            console.error('embed-memory: rate limit check failed')
            return json({ error: 'rate limit check unavailable' }, 503)
        }
        if (!budget.allowed) {
            return json(
                { error: 'rate_limited', retry_after_seconds: budget.retryAfterSeconds },
                429,
                rateLimitedHeaders(budget.retryAfterSeconds),
            )
        }

        const embeddingApiKey = Deno.env.get('GEMINI_API_KEY') ?? ''
        if (!embeddingApiKey) {
            console.error('embed-memory: GEMINI_API_KEY not set')
            return json({ error: 'AI service not configured' }, 500)
        }

        const embeddingResponse = await fetch('https://generativelanguage.googleapis.com/v1beta/openai/embeddings', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${embeddingApiKey}`,
            },
            body: JSON.stringify(embeddingRequestBody(input.value.content)),
        })

        if (!embeddingResponse.ok) {
            await embeddingResponse.body?.cancel()
            console.error('embed-memory: embedding API error', embeddingResponse.status)
            return json({ error: 'ai_provider_error' }, 502)
        }

        const embedding = extractEmbedding(await embeddingResponse.json())

        const { error: insertError } = await guard.admin
            .from('chat_memories')
            .insert({
                user_id: guard.userId,
                content: input.value.content,
                embedding,
                memory_type: input.value.memoryType,
                metadata: input.value.metadata,
            })

        if (insertError) {
            console.error('embed-memory: insert failed', insertError.code)
            throw insertError
        }

        return json({ success: true, dimensions: embedding.length })
    } catch (error) {
        console.error('embed-memory: failed', error instanceof Error ? error.name : 'unknown')
        return json({ error: 'internal error' }, 500)
    }
})
