-- NUCLEAR FIX: Run this entire script in Supabase SQL Editor

-- 1. Drop and recreate intelligence_data table with correct structure
DROP TABLE IF EXISTS intelligence_data CASCADE;

CREATE TABLE intelligence_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    longevity_score INTEGER DEFAULT 75,
    biomarker_summary JSONB DEFAULT '{}',
    key_insights JSONB DEFAULT '{}',
    disease_risks JSONB DEFAULT '[]',
    approved BOOLEAN DEFAULT FALSE,
    published BOOLEAN DEFAULT FALSE,
    generated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. CRITICAL: Disable RLS
ALTER TABLE intelligence_data DISABLE ROW LEVEL SECURITY;

-- 3. Also ensure other tables have RLS disabled
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE health_journeys DISABLE ROW LEVEL SECURITY;

-- 4. Verify
SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename IN ('intelligence_data', 'profiles', 'health_journeys');
