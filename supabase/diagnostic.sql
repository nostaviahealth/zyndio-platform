-- DIAGNOSTIC - Check Database Status
-- Run this to see what's actually in your database

-- 1. List all tables
SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- 2. Check if profiles table exists and see its structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 3. Check current profiles (should show admin)
SELECT id, name, email, role, created_at FROM public.profiles LIMIT 10;

-- 4. Check RLS status
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
