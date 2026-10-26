-- =============================================
-- CLEAN RESET SCRIPT
-- This drops existing objects and recreates everything
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- DROP EXISTING TABLES (in reverse dependency order)
-- =============================================
DROP TABLE IF EXISTS public.daily_journals CASCADE;
DROP TABLE IF EXISTS public.daily_bio_logs CASCADE;
DROP TABLE IF EXISTS public.meal_plans CASCADE;
DROP TABLE IF EXISTS public.intelligence_data CASCADE;
DROP TABLE IF EXISTS public.health_journeys CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- =============================================
-- 1. PROFILES TABLE
-- =============================================
CREATE TABLE public.profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'user',
    name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- =============================================
-- 2. PATIENTS TABLE
-- =============================================
CREATE TABLE public.patients (
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

-- =============================================
-- 3. DAILY BIO LOGS TABLE
-- =============================================
CREATE TABLE public.daily_bio_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    sleep_quality TEXT,
    stress_level INTEGER,
    energy_level INTEGER,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- =============================================
-- 4. DAILY JOURNALS TABLE
-- =============================================
CREATE TABLE public.daily_journals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- =============================================
-- 5. HEALTH JOURNEYS TABLE
-- =============================================
CREATE TABLE public.health_journeys (
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

-- =============================================
-- 6. INTELLIGENCE DATA TABLE
-- =============================================
CREATE TABLE public.intelligence_data (
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

-- =============================================
-- 7. MEAL PLANS TABLE
-- =============================================
CREATE TABLE public.meal_plans (
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

-- =============================================
-- SUCCESS
-- =============================================
SELECT 'SUCCESS! All tables created.' as result;
