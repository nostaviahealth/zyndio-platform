-- =============================================
-- FIX MEAL PLANS & INTELLIGENCE DATA RLS
-- Allows users to save/update their own data
-- =============================================

-- 1. FIX MEAL PLANS
DROP POLICY IF EXISTS "Users can view their own meal plans" ON public.meal_plans;
DROP POLICY IF EXISTS "Users can manage their own meal plans" ON public.meal_plans;
DROP POLICY IF EXISTS "Admins can manage all meal plans" ON public.meal_plans;

-- Policy to allow users to view, insert, and update their own meal plans
CREATE POLICY "Users can manage their own meal plans" 
    ON public.meal_plans FOR ALL 
    TO authenticated
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- Global policy for admins
CREATE POLICY "Admins can manage all meal plans" 
    ON public.meal_plans FOR ALL 
    TO authenticated
    USING (public.is_admin());


-- 2. FIX INTELLIGENCE DATA
DROP POLICY IF EXISTS "Users can view their own intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Users can manage their own intelligence" ON public.intelligence_data;
DROP POLICY IF EXISTS "Admins can manage all intelligence" ON public.intelligence_data;

-- Policy to allow users to view, insert, and update their own intelligence data
CREATE POLICY "Users can manage their own intelligence" 
    ON public.intelligence_data FOR ALL 
    TO authenticated
    USING (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
    WITH CHECK (profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- Global policy for admins
CREATE POLICY "Admins can manage all intelligence" 
    ON public.intelligence_data FOR ALL 
    TO authenticated
    USING (public.is_admin());
