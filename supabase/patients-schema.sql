-- ================================================
-- PATIENTS TABLE - Extended Schema
-- ================================================

CREATE TABLE IF NOT EXISTS public.patients (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  avatar_url TEXT,
  age INTEGER,
  bio_age INTEGER,
  health_grade TEXT CHECK (health_grade IN ('A', 'B', 'C', 'D', 'F')),
  primary_goal TEXT,
  joined_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'doctor', 'nutritionist')),
  is_premium BOOLEAN DEFAULT false,
  pace_of_aging DECIMAL(3,2),
  questionnaire_data JSONB,
  questionnaire_url TEXT,
  lab_report_url TEXT,
  lab_test_date TIMESTAMP WITH TIME ZONE,
  is_intelligence_verified BOOLEAN DEFAULT false,
  is_protocol_published BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS patients_user_id_idx ON public.patients(user_id);
CREATE INDEX IF NOT EXISTS patients_email_idx ON public.patients(email);
CREATE INDEX IF NOT EXISTS patients_stage_idx ON public.patients(stage);
CREATE INDEX IF NOT EXISTS patients_created_at_idx ON public.patients(created_at DESC);

-- ================================================
-- HEALTH JOURNEYS TABLE
-- ================================================

CREATE TABLE IF NOT EXISTS public.health_journeys (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  phases JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS health_journeys_patient_id_idx ON public.health_journeys(patient_id);
CREATE INDEX IF NOT EXISTS health_journeys_status_idx ON public.health_journeys(status);

-- ================================================
-- MEAL PLANS TABLE
-- ================================================

CREATE TABLE IF NOT EXISTS public.meal_plans (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
  week_number INTEGER NOT NULL,
  days JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(patient_id, week_number)
);

CREATE INDEX IF NOT EXISTS meal_plans_patient_id_idx ON public.meal_plans(patient_id);
CREATE INDEX IF NOT EXISTS meal_plans_week_idx ON public.meal_plans(week_number);

-- ================================================
-- TRIGGERS FOR UPDATED_AT
-- ================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON public.patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_health_journeys_updated_at BEFORE UPDATE ON public.health_journeys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meal_plans_updated_at BEFORE UPDATE ON public.meal_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================
-- ROW LEVEL SECURITY (Disabled for now)
-- ================================================

ALTER TABLE public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_journeys DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans DISABLE ROW LEVEL SECURITY;

-- ================================================
-- SYNC PATIENTS WITH PROFILES
-- ================================================

-- Create patient record when new user signs up (if using profiles)
CREATE OR REPLACE FUNCTION public.sync_patient_from_profile()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create patient if role is 'user' (not admin/doctor/nutritionist)
    IF NEW.role = 'user' THEN
        INSERT INTO public.patients (
            user_id,
            name,
            email,
            avatar_url,
            role
        ) VALUES (
            NEW.user_id,
            NEW.name,
            (SELECT email FROM auth.users WHERE id = NEW.user_id),
            NEW.avatar_url,
            NEW.role
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create patient when profile is created
DROP TRIGGER IF EXISTS on_profile_created ON public.profiles;
CREATE TRIGGER on_profile_created
    AFTER INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_patient_from_profile();
