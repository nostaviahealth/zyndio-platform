-- DISABLE RLS temporarily to test
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Or if you want to keep RLS enabled, run this instead:
-- DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
-- DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- CREATE POLICY "Enable read access for authenticated users" 
--   ON public.profiles FOR SELECT 
--   TO authenticated 
--   USING (true);

-- CREATE POLICY "Enable update for users based on user_id" 
--   ON public.profiles FOR UPDATE 
--   TO authenticated 
--   USING (auth.uid() = user_id);
