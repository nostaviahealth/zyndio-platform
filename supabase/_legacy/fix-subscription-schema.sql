-- ZYNDIO REVENUECAT SCHEMA FIX
-- This script ensures the profiles table has necessary columns for subscription tracking 
-- and that constraints are updated to allow 'plus' and 'free' values from RevenueCat.

-- 1. Ensure columns exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'is_premium') THEN
        ALTER TABLE public.profiles ADD COLUMN is_premium BOOLEAN DEFAULT FALSE NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'subscription_plan') THEN
        ALTER TABLE public.profiles ADD COLUMN subscription_plan TEXT DEFAULT 'free';
    END IF;
END $$;

-- 2. Update Check Constraint for subscription_plan
-- First, remove any existing check constraint if name is known or just attempt to replace
-- (Using a generic drop/create approach or checking existence)
DO $$ 
BEGIN
    ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_subscription_plan_check;
    
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_subscription_plan_check 
    CHECK (subscription_plan IN ('free', 'plus', 'pro', 'ultimate'));
EXCEPTION
    WHEN others THEN 
        RAISE NOTICE 'Constraint update failed: %', SQLERRM;
END $$;

-- 3. Ensure updated_at exists (from schema.sql it should, but belt and suspenders)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'updated_at') THEN
        ALTER TABLE public.profiles ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL;
    END IF;
END $$;
