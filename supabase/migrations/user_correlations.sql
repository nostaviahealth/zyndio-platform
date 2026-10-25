-- Run this script in the Supabase SQL editor to create the user_correlations table.
-- This version references public.profiles(user_id) for consistency with the Zyndio schema.

CREATE TABLE IF NOT EXISTS public.user_correlations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Links to public.profiles for consistent user management
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    signal_a TEXT NOT NULL,
    signal_b TEXT NOT NULL,
    coefficient FLOAT NOT NULL,
    sample_size INTEGER NOT NULL,
    direction TEXT NOT NULL,
    insight TEXT NOT NULL,
    strength TEXT NOT NULL,
    discovered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_confirmed_at TIMESTAMPTZ,
    confirmation_count INTEGER DEFAULT 1,
    is_novel BOOLEAN DEFAULT true,
    dismissed BOOLEAN DEFAULT false,
    
    UNIQUE(user_id, signal_a, signal_b)
);

-- Enable RLS
ALTER TABLE public.user_correlations ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own correlations" 
    ON public.user_correlations FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own correlations" 
    ON public.user_correlations FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own correlations" 
    ON public.user_correlations FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own correlations" 
    ON public.user_correlations FOR DELETE 
    USING (auth.uid() = user_id);
