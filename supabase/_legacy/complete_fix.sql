-- =============================================
-- COMPLETE FIX - RUN THIS IN SUPABASE SQL EDITOR
-- This adds the missing signup trigger and policies
-- =============================================

-- =============================================
-- 1. AUTO-CREATE PROFILE ON USER SIGNUP (CRITICAL!)
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create profile
    INSERT INTO public.profiles (user_id, name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email)
    );
    
    -- Create patient record
    INSERT INTO public.patients (user_id, name, email, stage)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.email,
        'questionnaire_pending'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- 2. FIX RLS POLICIES - Allow inserts
-- =============================================

-- Drop existing policies first (ignore errors)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Enable insert for service role" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own patient data" ON public.patients;
DROP POLICY IF EXISTS "Users can update own patient data" ON public.patients;
DROP POLICY IF EXISTS "Admins can manage all patients" ON public.patients;
DROP POLICY IF EXISTS "Enable insert for service role" ON public.patients;

-- Profiles policies
CREATE POLICY "Anyone can insert profiles" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin'));

-- Patients policies
CREATE POLICY "Anyone can insert patients" ON public.patients FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view own patient data" ON public.patients FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own patient data" ON public.patients FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all patients" ON public.patients FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role IN ('admin', 'doctor', 'nutritionist')));

-- =============================================
-- 3. BIO LOGS & JOURNALS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Users can insert own bio logs" ON public.daily_bio_logs;
DROP POLICY IF EXISTS "Users can view own bio logs" ON public.daily_bio_logs;
DROP POLICY IF EXISTS "Admins can view all bio logs" ON public.daily_bio_logs;
DROP POLICY IF EXISTS "Users can insert own journals" ON public.daily_journals;
DROP POLICY IF EXISTS "Users can view own journals" ON public.daily_journals;
DROP POLICY IF EXISTS "Admins can view all journals" ON public.daily_journals;

CREATE POLICY "Users can insert own bio logs" ON public.daily_bio_logs FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Users can view own bio logs" ON public.daily_bio_logs FOR SELECT USING (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Admins can view all bio logs" ON public.daily_bio_logs FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')));

CREATE POLICY "Users can insert own journals" ON public.daily_journals FOR INSERT WITH CHECK (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Users can view own journals" ON public.daily_journals FOR SELECT USING (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Admins can view all journals" ON public.daily_journals FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')));

-- =============================================
-- 4. HEALTH JOURNEYS & INTELLIGENCE POLICIES
-- =============================================
DROP POLICY IF EXISTS "Users can view published journeys" ON public.health_journeys;
DROP POLICY IF EXISTS "Admins can manage all journeys" ON public.health_journeys;
DROP POLICY IF EXISTS "Users can view published intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Admins can manage all intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Users can view published meal plans" ON public.meal_plans;
DROP POLICY IF EXISTS "Admins can manage all meal plans" ON public.meal_plans;

CREATE POLICY "Users can view published journeys" ON public.health_journeys FOR SELECT USING (published = TRUE AND patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all journeys" ON public.health_journeys FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('admin', 'doctor')));

CREATE POLICY "Users can view published intelligence" ON public.intelligence_data FOR SELECT USING (published = TRUE AND patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all intelligence" ON public.intelligence_data FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('admin', 'doctor')));

CREATE POLICY "Users can view published meal plans" ON public.meal_plans FOR SELECT USING (published = TRUE AND patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all meal plans" ON public.meal_plans FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('admin', 'nutritionist')));

-- =============================================
-- SUCCESS
-- =============================================
SELECT 'SUCCESS! Signup trigger and all policies created!' as result;
