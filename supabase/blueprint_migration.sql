-- =============================================
-- PROTOCOL BLUEPRINTS TABLE
-- Pre-generated daily task schedules for protocols
-- Run this in Supabase SQL Editor
-- =============================================

CREATE TABLE IF NOT EXISTS public.protocol_blueprints (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    protocol_id TEXT NOT NULL,
    duration_weeks INTEGER NOT NULL,
    start_date DATE NOT NULL,
    generation_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (generation_status IN ('pending', 'generating', 'complete', 'failed')),
    weeks_generated INTEGER NOT NULL DEFAULT 0,
    blueprint_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, protocol_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS protocol_blueprints_user_idx
    ON public.protocol_blueprints(user_id);
CREATE INDEX IF NOT EXISTS protocol_blueprints_lookup_idx
    ON public.protocol_blueprints(user_id, protocol_id);

-- Enable RLS
ALTER TABLE public.protocol_blueprints ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only access their own blueprints
CREATE POLICY "Users can manage own blueprints"
    ON public.protocol_blueprints FOR ALL
    USING (auth.uid() = user_id);

-- Auto-update timestamp trigger
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.protocol_blueprints
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
