-- SQL Migration: Add fcm_token to profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Index for performance when targeting specific devices
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- Update RLS policies if necessary (profiles are already manageable by users)
-- No changes needed to RLS as we already have "Users can update their own profile"
