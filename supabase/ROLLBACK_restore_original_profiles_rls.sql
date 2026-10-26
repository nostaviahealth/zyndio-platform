-- =============================================
-- ROLLBACK SCRIPT - RESTORE ORIGINAL PROFILES RLS
-- This restores the profiles table to the ORIGINAL policies from schema.sql
-- Run this IMMEDIATELY in Supabase SQL Editor to restore access
-- =============================================

-- 1. Drop all current policies (including the broken ones I created)
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- 2. Restore ORIGINAL policies from your schema.sql

-- Original: Users can view their own profile
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = user_id);

-- Original: Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Original: Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
    ON public.profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- =============================================
-- YOUR DATABASE IS NOW RESTORED TO ORIGINAL STATE
-- =============================================
