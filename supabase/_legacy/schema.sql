-- Zyndio Database Schema
-- Run this in Supabase SQL Editor after creating your project

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- PROFILES TABLE
-- Extends auth.users with custom fields and roles
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

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS profiles_user_id_idx ON public.profiles(user_id);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all profiles"
    ON public.profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- =============================================
-- PATIENTS TABLE
-- Patient data managed by admin/doctors
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

-- Patients RLS Policies
CREATE POLICY "Users can view their own patient data"
    ON public.patients FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all patients"
    ON public.patients FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')
        )
    );

-- =============================================
-- HEALTH JOURNEYS TABLE
-- AI-generated health protocols
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

-- Health Journeys RLS Policies
CREATE POLICY "Users can view their published health journeys"
    ON public.health_journeys FOR SELECT
    USING (
        published = TRUE AND
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can manage all health journeys"
    ON public.health_journeys FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'doctor')
        )
    );

-- =============================================
-- MEAL PLANS TABLE
-- Nutrition plans
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

-- Meal Plans RLS Policies
CREATE POLICY "Users can view their published meal plans"
    ON public.meal_plans FOR SELECT
    USING (
        published = TRUE AND
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can manage all meal plans"
    ON public.meal_plans FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'nutritionist')
        )
    );

-- =============================================
-- INTELLIGENCE DATA TABLE
-- Health intelligence analytics
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

-- Intelligence Data RLS Policies
CREATE POLICY "Users can view their published intelligence data"
    ON public.intelligence_data FOR SELECT
    USING (
        published = TRUE AND
        patient_id IN (SELECT id FROM public.patents WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can manage all intelligence data"
    ON public.intelligence_data FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'doctor')
        )
    );

-- =============================================
-- FUNCTIONS & TRIGGERS
-- Auto-update timestamps
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.patients
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.health_journeys
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.intelligence_data
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- AUTO-CREATE PROFILE ON USER SIGNUP
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id, name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- SEED DATA - Initial Admin User
-- Run these AFTER creating your first user via Supabase Auth
-- =============================================

-- This will be executed programmatically via the admin setup script
-- UPDATE public.profiles SET role = 'admin' WHERE user_id = (SELECT id FROM auth.users WHERE email = 'support@zyndio.example');
