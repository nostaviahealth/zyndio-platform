-- =============================================
-- RAG MEMORY SYSTEM FOR ZYNDIO INTELLIGENCE
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Create the chat_memories table
CREATE TABLE IF NOT EXISTS public.chat_memories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    memory_type TEXT NOT NULL DEFAULT 'conversation_summary'
        CHECK (memory_type IN ('conversation_summary', 'user_fact', 'health_event')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS chat_memories_user_id_idx ON public.chat_memories(user_id);
CREATE INDEX IF NOT EXISTS chat_memories_type_idx ON public.chat_memories(memory_type);
CREATE INDEX IF NOT EXISTS chat_memories_created_at_idx ON public.chat_memories(created_at DESC);

-- HNSW index for fast vector similarity search
CREATE INDEX IF NOT EXISTS chat_memories_embedding_idx 
    ON public.chat_memories 
    USING hnsw (embedding vector_cosine_ops);

-- 4. Enable Row Level Security
ALTER TABLE public.chat_memories ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own memories
CREATE POLICY "Users can view their own memories"
    ON public.chat_memories FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own memories"
    ON public.chat_memories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own memories"
    ON public.chat_memories FOR DELETE
    USING (auth.uid() = user_id);

-- Service role bypass for Edge Functions
CREATE POLICY "Service role has full access"
    ON public.chat_memories FOR ALL
    USING (auth.role() = 'service_role');

-- 5. Create the semantic search function
CREATE OR REPLACE FUNCTION match_memories(
    query_embedding vector(1536),
    match_user_id UUID,
    match_count INT DEFAULT 5,
    match_threshold FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    memory_type TEXT,
    metadata JSONB,
    similarity FLOAT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cm.id,
        cm.content,
        cm.memory_type,
        cm.metadata,
        1 - (cm.embedding <=> query_embedding) AS similarity,
        cm.created_at
    FROM public.chat_memories cm
    WHERE cm.user_id = match_user_id
      AND cm.embedding IS NOT NULL
      AND 1 - (cm.embedding <=> query_embedding) > match_threshold
    ORDER BY cm.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

COMMENT ON TABLE public.chat_memories IS 'Stores vectorized conversation memories for RAG-based recall in Zyndio Intelligence';
COMMENT ON FUNCTION match_memories IS 'Performs cosine similarity search on chat memories for a given user';
