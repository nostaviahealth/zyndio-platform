-- Add subscription_plan column to profiles table
-- Run this in Supabase SQL Editor

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'pro' 
CHECK (subscription_plan IN ('pro', 'ultimate'));

-- Update existing users to 'pro' if null
UPDATE profiles 
SET subscription_plan = 'pro' 
WHERE subscription_plan IS NULL;
