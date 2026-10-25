-- COMPLETE DATABASE FIX
-- This will completely remove patients table and use only profiles

-- Step 1: Drop all foreign key constraints referencing patients
ALTER TABLE IF EXISTS public.health_journeys DROP CONSTRAINT IF EXISTS health_journeys_patient_id_fkey;
ALTER TABLE IF EXISTS public.meal_plans DROP CONSTRAINT IF EXISTS meal_plans_patient_id_fkey;

-- Step 2: Drop patients table completely
DROP TABLE IF EXISTS public.patients CASCADE;

-- Step 3: Ensure profiles has all necessary columns
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
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Step 4: Make user_id nullable (so admin can create patients without auth accounts)
ALTER TABLE public.profiles ALTER COLUMN user_id DROP NOT NULL;

-- Step 5: Update foreign keys in related tables to point to profiles
ALTER TABLE IF EXISTS public.health_journeys 
  ADD CONSTRAINT health_journeys_profile_id_fkey 
  FOREIGN KEY (patient_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.meal_plans 
  ADD CONSTRAINT meal_plans_profile_id_fkey 
  FOREIGN KEY (patient_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Step 6: Add indexes
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_stage_idx ON public.profiles(stage);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);

-- Done! Now only profiles table exists
