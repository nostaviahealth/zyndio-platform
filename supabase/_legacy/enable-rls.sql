-- =============================================
-- CONSOLIDATED RLS ENABLEMENT
-- This script enables RLS on all tables and sets up non-recursive policies.
-- =============================================

-- 1. Create a helper function for admin checks (prevents infinite recursion)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid() 
        AND role IN ('admin', 'doctor', 'nutritionist')
    );
END;
$$;

-- 2. Enable RLS on all relevant tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intelligence_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_bio_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_journals ENABLE ROW LEVEL SECURITY;

-- 3. PROFILES POLICIES
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can insert profiles" ON public.profiles;

CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.is_admin());
CREATE POLICY "Service role can do everything on profiles" ON public.profiles FOR ALL USING (true) WITH CHECK (true);

-- 4. MEAL PLANS POLICIES
DROP POLICY IF EXISTS "Users can view their own meal plans" ON public.meal_plans;
DROP POLICY IF EXISTS "Users can manage their own meal plans" ON public.meal_plans;
DROP POLICY IF EXISTS "Admins can manage all meal plans" ON public.meal_plans;

CREATE POLICY "Users can manage their own meal plans" ON public.meal_plans FOR ALL 
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

CREATE POLICY "Admins can manage all meal plans" ON public.meal_plans FOR ALL USING (public.is_admin());

-- 5. HEALTH JOURNEYS POLICIES
DROP POLICY IF EXISTS "Users can view published journeys" ON public.health_journeys;
DROP POLICY IF EXISTS "Admins can manage all journeys" ON public.health_journeys;

CREATE POLICY "Users can view their own journeys" ON public.health_journeys FOR SELECT 
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all journeys" ON public.health_journeys FOR ALL USING (public.is_admin());

-- 6. INTELLIGENCE DATA POLICIES
DROP POLICY IF EXISTS "Users can view their own intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Users can manage their own intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Admins can manage all intelligence" ON public.intelligence_data;

CREATE POLICY "Users can manage their own intelligence" ON public.intelligence_data FOR ALL 
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

CREATE POLICY "Admins can manage all intelligence" ON public.intelligence_data FOR ALL USING (public.is_admin());

-- 7. BIO LOGS & JOURNALS
DROP POLICY IF EXISTS "Users can insert own bio logs" ON public.daily_bio_logs;
DROP POLICY IF EXISTS "Users can view own bio logs" ON public.daily_bio_logs;
DROP POLICY IF EXISTS "Users can insert own journals" ON public.daily_journals;
DROP POLICY IF EXISTS "Users can view own journals" ON public.daily_journals;

CREATE POLICY "Users can manage own bio logs" ON public.daily_bio_logs FOR ALL 
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
CREATE POLICY "Users can manage own journals" ON public.daily_journals FOR ALL 
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
CREATE POLICY "Admins can view all logs" ON public.daily_bio_logs FOR SELECT USING (public.is_admin());
CREATE POLICY "Admins can view all journals" ON public.daily_journals FOR SELECT USING (public.is_admin());

-- =============================================
-- RLS ENABLED SUCCESSFULLY
-- =============================================
