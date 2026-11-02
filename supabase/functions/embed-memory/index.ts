import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2.118.0"

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
        const { user_id, content, memory_type, metadata } = await req.json()

        if (!user_id || !content) {
            return new Response(
                JSON.stringify({ error: 'user_id and content are required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 1. Generate embedding via Gemini
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
                input: content,
                model: embeddingDeployment,
            }),
        })

        if (!embeddingResponse.ok) {
            const errorBody = await embeddingResponse.text()
            console.error('Embedding API Error:', embeddingResponse.status, errorBody)
            throw new Error(`Embedding API failed: ${embeddingResponse.status}`)
        }

        const embeddingData = await embeddingResponse.json()
        const embedding = embeddingData.data[0].embedding

        // 2. Store in Supabase
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        console.log(`Storing embedding for user ${user_id}, type: ${memory_type}, content length: ${content.length}, dims: ${embedding.length}`)

        const { error: insertError } = await supabase
            .from('chat_memories')
            .insert({
                user_id,
                content,
                embedding: embedding, // Pass raw array
                memory_type: memory_type ?? 'conversation_summary',
                metadata: metadata ?? {},
            })

        if (insertError) {
            console.error('Insert Error:', insertError)
            throw insertError
        }

        return new Response(
            JSON.stringify({ success: true, dimensions: embedding.length }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Function Error:', error)
        return new Response(
            JSON.stringify({ error: error instanceof Error ? error.message : 'internal error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
