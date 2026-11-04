import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { guardPatientAiRequest } from '../_shared/patientAiGuard.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        let body: Record<string, unknown>
        try {
            body = await req.json()
        } catch {
            body = {}
        }
        const { user_id, query, match_count } = body as Record<string, any>

        // Signed-in patient, own memories only, memory feature switched on.
        const guard = await guardPatientAiRequest(req, user_id, 'memory')
        if (!guard.ok) {
            return new Response(
                JSON.stringify(guard.body),
                { status: guard.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (!user_id || !query) {
            return new Response(
                JSON.stringify({ error: 'user_id and query are required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 1. Generate embedding for the query
        const embeddingApiKey = Deno.env.get('GEMINI_API_KEY') ?? ''
        const embeddingDeployment = 'gemini-embedding-001'

        const embeddingUrl = `https://generativelanguage.googleapis.com/v1beta/openai/embeddings`

        const embeddingResponse = await fetch(embeddingUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${embeddingApiKey}`,
            },
            body: JSON.stringify({
                input: query,
                model: embeddingDeployment,
            }),
        })

        if (!embeddingResponse.ok) {
            console.error('search-memory: embedding API error', embeddingResponse.status)
            throw new Error(`Embedding API failed: ${embeddingResponse.status}`)
        }

        const embeddingData = await embeddingResponse.json()
        const queryEmbedding = embeddingData.data[0].embedding

        // 2. Call the match_memories RPC function
        const supabase = guard.admin

        const { data: memories, error: rpcError } = await supabase.rpc('match_memories', {
            query_embedding: JSON.stringify(queryEmbedding),
            match_user_id: guard.userId,
            match_count: match_count ?? 5,
            match_threshold: 0.3,
        })

        if (rpcError) {
            console.error('search-memory: RPC failed', rpcError.code)
            throw rpcError
        }

        return new Response(
            JSON.stringify({ memories: memories ?? [] }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('search-memory: failed', error instanceof Error ? error.name : 'unknown')
        return new Response(
            JSON.stringify({ error: 'internal error', memories: [] }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
