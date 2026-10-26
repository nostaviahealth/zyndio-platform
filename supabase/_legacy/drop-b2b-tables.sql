-- =============================================
-- DROP B2B TABLES FROM SUPABASE
-- Run this in Supabase SQL Editor to remove all B2B data
-- =============================================

-- Drop tables (in order due to foreign key constraints)
DROP TABLE IF EXISTS public.b2b_risk_results CASCADE;
DROP TABLE IF EXISTS public.b2b_biomarkers CASCADE;
DROP TABLE IF EXISTS public.b2b_lab_reports CASCADE;
DROP TABLE IF EXISTS public.b2b_partners CASCADE;

-- Confirm deletion
SELECT 'B2B tables dropped successfully!' as message;
