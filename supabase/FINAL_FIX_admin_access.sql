-- =============================================
-- FINAL FIX: Restore Admin Access Without Recursion
-- This fixes the infinite recursion error by using SECURITY DEFINER
-- =============================================

-- 1. Create a function that checks admin status WITHOUT triggering RLS recursion
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- This bypasses RLS, breaking the recursion
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

-- 2. Drop existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- 3. Recreate policies with the non-recursive function

-- Users can view their own profile
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Admins can view ALL profiles (NO MORE RECURSION!)
CREATE POLICY "Admins can view all profiles"
    ON public.profiles FOR SELECT
    USING (public.is_admin());

-- =============================================
-- ADMIN ACCESS RESTORED - NO RECURSION ERROR
-- =============================================
