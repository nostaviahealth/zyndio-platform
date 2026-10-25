-- =============================================
-- STANDALONE SETUP SCRIPT
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- 1. PROFILES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'doctor', 'nutritionist')),
    name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS profiles_user_id_idx ON public.profiles(user_id);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 2. PATIENTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    age INTEGER,
    bio_age INTEGER,
    health_grade TEXT,
    primary_goal TEXT,
    is_premium BOOLEAN DEFAULT FALSE NOT NULL,
    pace_of_aging DECIMAL DEFAULT 1.0 NOT NULL,
    avatar_url TEXT,
    stage TEXT DEFAULT 'profile_creation' NOT NULL,
    preferences JSONB,
    doctor_notes TEXT,
    nutritionist_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS patients_user_id_idx ON public.patients(user_id);
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 3. DAILY BIO LOGS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.daily_bio_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    sleep_quality TEXT CHECK (sleep_quality IN ('Poor', 'Fair', 'Good', 'Great')),
    stress_level INTEGER CHECK (stress_level >= 1 AND stress_level <= 5),
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 5),
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_bio_logs_patient_id_idx ON public.daily_bio_logs(patient_id);
ALTER TABLE public.daily_bio_logs ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 4. DAILY JOURNALS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.daily_journals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_journals_patient_id_idx ON public.daily_journals(patient_id);
ALTER TABLE public.daily_journals ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 5. HEALTH JOURNEYS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.health_journeys (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    overview TEXT,
    phases JSONB NOT NULL DEFAULT '[]'::jsonb,
    published BOOLEAN DEFAULT FALSE NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS health_journeys_patient_id_idx ON public.health_journeys(patient_id);
ALTER TABLE public.health_journeys ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 6. INTELLIGENCE DATA TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.intelligence_data (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    overall_score INTEGER,
    biomarkers_score INTEGER,
    lifestyle_score INTEGER,
    risk_factors_score INTEGER,
    health_domains JSONB,
    disease_risks JSONB,
    approved BOOLEAN DEFAULT FALSE NOT NULL,
    published BOOLEAN DEFAULT FALSE NOT NULL,
    generated_at TIMESTAMP WITH TIME ZONE,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS intelligence_data_patient_id_idx ON public.intelligence_data(patient_id);
ALTER TABLE public.intelligence_data ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 7. MEAL PLANS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.meal_plans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    days JSONB NOT NULL DEFAULT '[]'::jsonb,
    approved BOOLEAN DEFAULT FALSE NOT NULL,
    published BOOLEAN DEFAULT FALSE NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS meal_plans_patient_id_idx ON public.meal_plans(patient_id);
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;

-- =============================================
-- SUCCESS MESSAGE
-- =============================================
SELECT 'All tables created successfully!' as result;
