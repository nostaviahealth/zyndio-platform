-- Run this script in the Supabase SQL editor to create the menstrual_logs table.

CREATE TABLE IF NOT EXISTS public.menstrual_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE,
    flow_intensity TEXT CHECK (flow_intensity IN ('light', 'medium', 'heavy', 'spotting')),
    symptoms JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.menstrual_logs ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own menstrual logs" 
    ON public.menstrual_logs FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own menstrual logs" 
    ON public.menstrual_logs FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own menstrual logs" 
    ON public.menstrual_logs FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own menstrual logs" 
    ON public.menstrual_logs FOR DELETE 
    USING (auth.uid() = user_id);
