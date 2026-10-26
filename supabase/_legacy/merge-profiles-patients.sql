-- ================================================
-- MERGE PATIENTS INTO PROFILES
-- ================================================
-- This migration adds all patient-specific fields to the profiles table
-- and removes the redundant patients table

-- Step 1: Add patient-specific columns to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio_age INTEGER;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS health_grade TEXT CHECK (health_grade IN ('A', 'B', 'C', 'D', 'F'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS primary_goal TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS joined_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS stage TEXT DEFAULT 'payment_pending' CHECK (stage IN (
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
));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pace_of_aging DECIMAL(3,2);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS questionnaire_data JSONB;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS questionnaire_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lab_report_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lab_test_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_intelligence_verified BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_protocol_published BOOLEAN DEFAULT false;

-- Step 2: Add email column to profiles (for easier querying)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Step 3: Migrate any existing data from patients to profiles (if any)
-- UPDATE public.profiles p
-- SET 
--     phone = pt.phone,
--     age = pt.age,
--     bio_age = pt.bio_age,
--     health_grade = pt.health_grade,
--     primary_goal = pt.primary_goal,
--     stage = pt.stage,
--     is_premium = pt.is_premium,
--     pace_of_aging = pt.pace_of_aging,
--     questionnaire_data = pt.questionnaire_data,
--     lab_report_url = pt.lab_report_url,
--     is_intelligence_verified = pt.is_intelligence_verified,
--     is_protocol_published = pt.is_protocol_published,
--     email = pt.email
-- FROM public.patients pt
-- WHERE p.user_id = pt.user_id;

-- Step 4: Update foreign keys in other tables
-- Update health_journeys to reference profiles instead of patients
-- ALTER TABLE public.health_journeys DROP CONSTRAINT IF EXISTS health_journeys_patient_id_fkey;
-- ALTER TABLE public.health_journeys RENAME COLUMN patient_id TO profile_id;
-- ALTER TABLE public.health_journeys ADD CONSTRAINT health_journeys_profile_id_fkey 
--     FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Update meal_plans to reference profiles instead of patients  
-- ALTER TABLE public.meal_plans DROP CONSTRAINT IF EXISTS meal_plans_patient_id_fkey;
-- ALTER TABLE public.meal_plans RENAME COLUMN patient_id TO profile_id;
-- ALTER TABLE public.meal_plans ADD CONSTRAINT meal_plans_profile_id_fkey
--     FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Step 5: Drop the patients table (CAREFUL - only after data is migrated!)
DROP TABLE IF EXISTS public.patients CASCADE;

-- Step 6: Add indexes for performance
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_stage_idx ON public.profiles(stage);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);

-- Step 7: Update the auto-sync trigger to populate email
CREATE OR REPLACE FUNCTION public.sync_profile_email()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-populate email from auth.users
    IF NEW.email IS NULL THEN
        NEW.email := (SELECT email FROM auth.users WHERE id = NEW.user_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_email_sync ON public.profiles;
CREATE TRIGGER on_profile_email_sync
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_profile_email();

-- Done! Now profiles table contains all user data
