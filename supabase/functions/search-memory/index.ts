import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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
        const { user_id, query, match_count } = await req.json()

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
            const errorBody = await embeddingResponse.text()
            console.error('Embedding API Error:', embeddingResponse.status, errorBody)
            throw new Error(`Embedding API failed: ${embeddingResponse.status}`)
        }

        const embeddingData = await embeddingResponse.json()
        const queryEmbedding = embeddingData.data[0].embedding

        // 2. Call the match_memories RPC function
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { data: memories, error: rpcError } = await supabase.rpc('match_memories', {
            query_embedding: JSON.stringify(queryEmbedding),
            match_user_id: user_id,
            match_count: match_count ?? 5,
            match_threshold: 0.3,
        })

        if (rpcError) {
            console.error('RPC Error:', rpcError)
            throw rpcError
        }

        return new Response(
            JSON.stringify({ memories: memories ?? [] }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Function Error:', error)
        return new Response(
            JSON.stringify({ error: error.message, memories: [] }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
