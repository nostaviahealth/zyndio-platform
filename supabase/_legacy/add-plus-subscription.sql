-- Migration: Add 'plus' to subscription_plan check constraint
-- Run this in the Supabase SQL Editor

-- 1. Identify the existing constraint name (usually profiles_subscription_plan_check)
-- 2. Drop the existing constraint
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_subscription_plan_check;

-- 3. Add the new constraint with 'plus' included
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_subscription_plan_check 
CHECK (subscription_plan IN ('free', 'baseline', 'plus', 'pro', 'ultimate'));

-- 4. Update the column comment
COMMENT ON COLUMN public.profiles.subscription_plan IS 'Subscription tier: free, baseline, plus, pro, or ultimate';
