-- =============================================
-- MASTER DATABASE FIX
-- Run this entire script in Supabase SQL Editor
-- This consolidates all schema fixes into one reliable script
-- =============================================

-- =============================================
-- STEP 1: ENSURE PROFILES TABLE HAS ALL REQUIRED COLUMNS
-- =============================================

-- Enable UUID extension if not exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Add all patient-related columns to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio_age INTEGER;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS health_grade TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS primary_goal TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS joined_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS stage TEXT DEFAULT 'payment_pending';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pace_of_aging DECIMAL(3,2);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS questionnaire_data JSONB;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS questionnaire_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lab_report_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lab_test_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_intelligence_verified BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_protocol_published BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'pro';

-- Make user_id nullable (so admin can create patients without auth accounts)
ALTER TABLE public.profiles ALTER COLUMN user_id DROP NOT NULL;

-- Add indexes
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_stage_idx ON public.profiles(stage);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);

-- =============================================
-- STEP 2: HANDLE HEALTH_JOURNEYS TABLE
-- =============================================

-- Drop old patient_id foreign key if exists
ALTER TABLE IF EXISTS public.health_journeys DROP CONSTRAINT IF EXISTS health_journeys_patient_id_fkey;
ALTER TABLE IF EXISTS public.health_journeys DROP CONSTRAINT IF EXISTS health_journeys_profile_id_fkey;

-- Rename patient_id to profile_id if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'health_journeys' AND column_name = 'patient_id') THEN
        -- Check if profile_id doesn't exist, then rename
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'health_journeys' AND column_name = 'profile_id') THEN
            ALTER TABLE public.health_journeys RENAME COLUMN patient_id TO profile_id;
        END IF;
    END IF;
END $$;

-- Add profile_id column if it doesn't exist at all
ALTER TABLE public.health_journeys ADD COLUMN IF NOT EXISTS profile_id UUID;

-- Add foreign key constraint
ALTER TABLE public.health_journeys 
  ADD CONSTRAINT health_journeys_profile_id_fkey 
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Add status column if not exists
ALTER TABLE public.health_journeys ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'draft';

-- =============================================
-- STEP 3: HANDLE INTELLIGENCE_DATA TABLE
-- =============================================

-- Drop and recreate intelligence_data with correct structure
DROP TABLE IF EXISTS public.intelligence_data CASCADE;

CREATE TABLE public.intelligence_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    longevity_score INTEGER DEFAULT 75,
    biomarker_summary JSONB DEFAULT '{}',
    key_insights JSONB DEFAULT '{}',
    disease_risks JSONB DEFAULT '[]',
    approved BOOLEAN DEFAULT FALSE,
    published BOOLEAN DEFAULT FALSE,
    generated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS intelligence_data_profile_id_idx ON public.intelligence_data(profile_id);

-- =============================================
-- STEP 4: HANDLE MEAL_PLANS TABLE
-- =============================================

-- Drop old constraint if exists
ALTER TABLE IF EXISTS public.meal_plans DROP CONSTRAINT IF EXISTS meal_plans_patient_id_fkey;
ALTER TABLE IF EXISTS public.meal_plans DROP CONSTRAINT IF EXISTS meal_plans_profile_id_fkey;

-- Rename patient_id to profile_id if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meal_plans' AND column_name = 'patient_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meal_plans' AND column_name = 'profile_id') THEN
            ALTER TABLE public.meal_plans RENAME COLUMN patient_id TO profile_id;
        END IF;
    END IF;
END $$;

-- Add profile_id column if it doesn't exist at all
ALTER TABLE public.meal_plans ADD COLUMN IF NOT EXISTS profile_id UUID;

-- Add foreign key
ALTER TABLE public.meal_plans 
  ADD CONSTRAINT meal_plans_profile_id_fkey 
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- =============================================
-- STEP 5: CREATE/FIX DAILY_BIO_LOGS TABLE
-- =============================================

DROP TABLE IF EXISTS public.daily_bio_logs CASCADE;

CREATE TABLE public.daily_bio_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    sleep_quality TEXT CHECK (sleep_quality IN ('Poor', 'Fair', 'Good', 'Great')),
    stress_level INTEGER CHECK (stress_level >= 1 AND stress_level <= 5),
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 5),
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_bio_logs_profile_id_idx ON public.daily_bio_logs(profile_id);
CREATE INDEX IF NOT EXISTS daily_bio_logs_logged_at_idx ON public.daily_bio_logs(logged_at);

-- =============================================
-- STEP 6: CREATE/FIX DAILY_JOURNALS TABLE
-- =============================================

DROP TABLE IF EXISTS public.daily_journals CASCADE;

CREATE TABLE public.daily_journals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_journals_profile_id_idx ON public.daily_journals(profile_id);
CREATE INDEX IF NOT EXISTS daily_journals_logged_at_idx ON public.daily_journals(logged_at);

-- =============================================
-- STEP 7: DISABLE ROW LEVEL SECURITY (for development)
-- =============================================

ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_journeys DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.intelligence_data DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_bio_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_journals DISABLE ROW LEVEL SECURITY;

-- =============================================
-- STEP 8: DROP OLD PATIENTS TABLE (no longer needed)
-- =============================================

DROP TABLE IF EXISTS public.patients CASCADE;

-- =============================================
-- STEP 9: VERIFY THE FIX
-- =============================================

SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'health_journeys', 'intelligence_data', 'meal_plans', 'daily_bio_logs', 'daily_journals')
ORDER BY table_name, ordinal_position;
