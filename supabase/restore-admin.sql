-- Restore Admin Access
-- Run this after fresh-start.sql to recreate admin profile

-- Find your user ID and create admin profile
INSERT INTO public.profiles (
    user_id,
    name,
    email,
    role,
    avatar_url,
    stage,
    is_premium,
    joined_date
)
SELECT 
    id as user_id,
    COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)) as name,
    email,
    'admin' as role,
    'https://ui-avatars.com/api/?background=1e293b&color=fff&name=Admin' as avatar_url,
    'protocol_ready' as stage,
    true as is_premium,
    NOW() as joined_date
FROM auth.users
WHERE email IN ('support@zyndio.example', 'adityasinghinx@gmail.com')
ON CONFLICT (email) DO UPDATE SET role = 'admin';

-- Verify admin profiles created
SELECT id, name, email, role FROM public.profiles WHERE role = 'admin';
