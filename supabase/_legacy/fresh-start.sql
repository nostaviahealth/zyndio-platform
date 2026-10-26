-- ================================================================
-- COMPLETE DATABASE RESET - START FRESH
-- ================================================================
-- This will delete EVERYTHING and rebuild from scratch
-- WARNING: This will delete all existing data!

-- Step 1: DROP ALL TABLES
DROP TABLE IF EXISTS public.meal_plans CASCADE;
DROP TABLE IF EXISTS public.health_journeys CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Step 2: CREATE PROFILES TABLE (THE ONLY USER TABLE)
CREATE TABLE public.profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Basic Info
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'doctor', 'nutritionist')),
  
  -- Patient Health Data
  age INTEGER,
  bio_age INTEGER,
  health_grade TEXT CHECK (health_grade IN ('A', 'B', 'C', 'D', 'F')),
  primary_goal TEXT,
  pace_of_aging DECIMAL(3,2),
  
  -- Onboarding Status
  stage TEXT DEFAULT 'payment_pending' CHECK (stage IN (
    'payment_pending',
    'profile_creation',
    'lab_test_scheduled',
    'questionnaire_pending',
    'lab_processing',
    'intelligence_generation',
    'doctor_verification',
    'consultation_scheduled',
    'protocol_creation',
    'protocol_ready'
  )),
  joined_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_premium BOOLEAN DEFAULT false,
  
  -- Data Files
  questionnaire_data JSONB,
  questionnaire_url TEXT,
  lab_report_url TEXT,
  lab_test_date TIMESTAMP WITH TIME ZONE,
  
  -- Status Flags
  is_intelligence_verified BOOLEAN DEFAULT false,
  is_protocol_published BOOLEAN DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(email)
);

-- Step 3: CREATE HEALTH JOURNEYS TABLE
CREATE TABLE public.health_journeys (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  phases JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: CREATE MEAL PLANS TABLE
CREATE TABLE public.meal_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  week_number INTEGER NOT NULL,
  days JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(profile_id, week_number)
);

-- Step 5: CREATE INDEXES FOR PERFORMANCE
CREATE INDEX profiles_user_id_idx ON public.profiles(user_id);
CREATE INDEX profiles_email_idx ON public.profiles(email);
CREATE INDEX profiles_role_idx ON public.profiles(role);
CREATE INDEX profiles_stage_idx ON public.profiles(stage);
CREATE INDEX profiles_created_at_idx ON public.profiles(created_at DESC);

CREATE INDEX health_journeys_profile_id_idx ON public.health_journeys(profile_id);
CREATE INDEX health_journeys_status_idx ON public.health_journeys(status);

CREATE INDEX meal_plans_profile_id_idx ON public.meal_plans(profile_id);
CREATE INDEX meal_plans_week_idx ON public.meal_plans(week_number);

-- Step 6: CREATE UPDATE TRIGGER FOR updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_health_journeys_updated_at BEFORE UPDATE ON public.health_journeys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meal_plans_updated_at BEFORE UPDATE ON public.meal_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 7: AUTO-CREATE PROFILE ON USER SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        user_id,
        name,
        email,
        role,
        avatar_url,
        stage,
        is_premium,
        joined_date
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.email,
        'user',
        'https://ui-avatars.com/api/?background=1e293b&color=fff&name=' || COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        'payment_pending',
        false,
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Step 8: DISABLE RLS (for now - enable later with proper policies)
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_journeys DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans DISABLE ROW LEVEL SECURITY;

-- ================================================================
-- DONE! Fresh database with ONLY profiles table (no patients table)
-- ================================================================
