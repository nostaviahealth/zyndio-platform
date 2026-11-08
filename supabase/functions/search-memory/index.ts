import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { guardPatientAiRequest } from '../_shared/patientAiGuard.ts'
import { rateLimitedHeaders } from '../_shared/intelligenceRateLimit.ts'
import {
    consumeMemoryBudget,
    embeddingRequestBody,
    extractEmbedding,
    parseSearchRequest,
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
// -> provider -> match_memories (service role, guard.userId only).
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

        if (!body.user_id) return json({ error: 'user_id and query are required' }, 400)
        const input = parseSearchRequest(body)
        if (!input.ok) return json({ error: input.error }, 400)

        let budget
        try {
            budget = await consumeMemoryBudget(guard.admin, guard.userId)
        } catch {
            console.error('search-memory: rate limit check failed')
            return json({ error: 'rate limit check unavailable', memories: [] }, 503)
        }
        if (!budget.allowed) {
            return json(
                { error: 'rate_limited', retry_after_seconds: budget.retryAfterSeconds, memories: [] },
                429,
                rateLimitedHeaders(budget.retryAfterSeconds),
            )
        }

        const embeddingApiKey = Deno.env.get('GEMINI_API_KEY') ?? ''
        if (!embeddingApiKey) {
            console.error('search-memory: GEMINI_API_KEY not set')
            return json({ error: 'AI service not configured', memories: [] }, 500)
        }

        const embeddingResponse = await fetch('https://generativelanguage.googleapis.com/v1beta/openai/embeddings', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${embeddingApiKey}`,
            },
            body: JSON.stringify(embeddingRequestBody(input.value.query)),
        })

        if (!embeddingResponse.ok) {
            await embeddingResponse.body?.cancel()
            console.error('search-memory: embedding API error', embeddingResponse.status)
            return json({ error: 'ai_provider_error', memories: [] }, 502)
        }

        const queryEmbedding = extractEmbedding(await embeddingResponse.json())

        const { data: memories, error: rpcError } = await guard.admin.rpc('match_memories', {
            query_embedding: JSON.stringify(queryEmbedding),
            match_user_id: guard.userId,
            match_count: input.value.matchCount,
            match_threshold: 0.3,
        })

        if (rpcError) {
            console.error('search-memory: RPC failed', rpcError.code)
            throw rpcError
        }

        return json({ memories: memories ?? [] })
    } catch (error) {
        console.error('search-memory: failed', error instanceof Error ? error.name : 'unknown')
        return json({ error: 'internal error', memories: [] }, 500)
    }
})
