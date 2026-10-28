-- =============================================
-- FIX USER PROFILE STAGE
-- Run this in Supabase SQL Editor
-- =============================================

-- Set your profile to 'protocol_ready' so you can see the full dashboard
UPDATE public.profiles 
SET 
    stage = 'protocol_ready',
    -- Also ensure you have basic profile data
    is_intelligence_verified = true,
    is_protocol_published = true
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'adityasinghinx@gmail.com'
);

-- Verify the update
SELECT id, name, email, role, stage, is_intelligence_verified, is_protocol_published 
FROM public.profiles 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'adityasinghinx@gmail.com');
