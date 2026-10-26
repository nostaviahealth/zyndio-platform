-- =============================================
-- MAKE USER AN ADMIN
-- Run this in Supabase SQL Editor
-- =============================================

-- First, ensure the user exists in profiles and set their role to admin
UPDATE public.profiles 
SET role = 'admin'
WHERE email = 'adityasinghinx@gmail.com';

-- If the above didn't update any rows (user might not have email in profiles),
-- try to update based on auth.users email instead
UPDATE public.profiles 
SET role = 'admin'
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'adityasinghinx@gmail.com'
);

-- Verify the change
SELECT id, name, email, role, user_id 
FROM public.profiles 
WHERE email = 'adityasinghinx@gmail.com' 
   OR user_id = (SELECT id FROM auth.users WHERE email = 'adityasinghinx@gmail.com');
