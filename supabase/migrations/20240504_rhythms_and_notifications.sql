
-- 1. Create or Update daily_rhythms table
CREATE TABLE IF NOT EXISTS public.daily_rhythms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    summary TEXT,
    tasks JSONB NOT NULL DEFAULT '[]'::jsonb,
    source TEXT DEFAULT 'generated',
    morning_text TEXT,
    lunch_text TEXT,
    evening_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, date)
);

-- Ensure RLS is enabled
ALTER TABLE public.daily_rhythms ENABLE ROW LEVEL SECURITY;

-- RLS Policies for daily_rhythms
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_rhythms' AND policyname = 'Users can view their own rhythms') THEN
        CREATE POLICY "Users can view their own rhythms" ON public.daily_rhythms FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_rhythms' AND policyname = 'Users can insert their own rhythms') THEN
        CREATE POLICY "Users can insert their own rhythms" ON public.daily_rhythms FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_rhythms' AND policyname = 'Users can update their own rhythms') THEN
        CREATE POLICY "Users can update their own rhythms" ON public.daily_rhythms FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END $$;

-- Add missing columns if table already existed without them
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_rhythms' AND column_name='morning_text') THEN
        ALTER TABLE public.daily_rhythms ADD COLUMN morning_text TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_rhythms' AND column_name='lunch_text') THEN
        ALTER TABLE public.daily_rhythms ADD COLUMN lunch_text TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_rhythms' AND column_name='evening_text') THEN
        ALTER TABLE public.daily_rhythms ADD COLUMN evening_text TEXT;
    END IF;
END $$;


-- 2. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    action_route TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can view their own notifications') THEN
        CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update their own notifications') THEN
        CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can insert their own notifications') THEN
        CREATE POLICY "Users can insert their own notifications" ON public.notifications FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- Indices for performance
CREATE INDEX IF NOT EXISTS daily_rhythms_user_id_date_idx ON public.daily_rhythms (user_id, date);
CREATE INDEX IF NOT EXISTS notifications_user_id_created_at_idx ON public.notifications (user_id, created_at DESC);
