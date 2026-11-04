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
        const { user_id, content, memory_type, metadata } = body as Record<string, any>

        // Signed-in patient, own memories only, memory feature switched on.
        const guard = await guardPatientAiRequest(req, user_id, 'memory')
        if (!guard.ok) {
            return new Response(
                JSON.stringify(guard.body),
                { status: guard.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

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
            console.error('embed-memory: embedding API error', embeddingResponse.status)
            throw new Error(`Embedding API failed: ${embeddingResponse.status}`)
        }

        const embeddingData = await embeddingResponse.json()
        const embedding = embeddingData.data[0].embedding

        // 2. Store in Supabase
        const supabase = guard.admin

        const { error: insertError } = await supabase
            .from('chat_memories')
            .insert({
                user_id: guard.userId,
                content,
                embedding: embedding, // Pass raw array
                memory_type: memory_type ?? 'conversation_summary',
                metadata: metadata ?? {},
            })

        if (insertError) {
            console.error('embed-memory: insert failed', insertError.code)
            throw insertError
        }

        return new Response(
            JSON.stringify({ success: true, dimensions: embedding.length }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('embed-memory: failed', error instanceof Error ? error.name : 'unknown')
        return new Response(
            JSON.stringify({ error: 'internal error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
