-- =============================================
-- FIX LAB REPORTS RLS
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. Ensure RLS is enabled
ALTER TABLE IF EXISTS public.lab_reports ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own lab reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can insert their own lab reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Users can delete their own lab reports" ON public.lab_reports;
DROP POLICY IF EXISTS "Admins can manage all lab reports" ON public.lab_reports;

-- 3. Create Policies

-- READ: Users can view reports linked to their profile
CREATE POLICY "Users can view their own lab reports"
ON public.lab_reports FOR SELECT
USING (
    profile_id IN (
        SELECT id FROM public.profiles 
        WHERE user_id = auth.uid()
    )
);

-- INSERT: Users can upload reports to their profile
CREATE POLICY "Users can insert their own lab reports"
ON public.lab_reports FOR INSERT
WITH CHECK (
    profile_id IN (
        SELECT id FROM public.profiles 
        WHERE user_id = auth.uid()
    )
);

-- DELETE: Users can delete their own reports (This was missing/broken!)
CREATE POLICY "Users can delete their own lab reports"
ON public.lab_reports FOR DELETE
USING (
    profile_id IN (
        SELECT id FROM public.profiles 
        WHERE user_id = auth.uid()
    )
);

-- ADMIN: Admins can do everything
CREATE POLICY "Admins can manage all lab reports"
ON public.lab_reports FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')
    )
);

-- 4. Verify Access (Optional)
-- This assumes public.profiles uses user_id correctly mapping to auth.uid()
