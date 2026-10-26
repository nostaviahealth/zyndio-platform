-- =============================================
-- ADD REPORT TYPE TO LAB REPORTS
-- Adds support for advanced health panels
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. Add new columns to lab_reports
ALTER TABLE public.lab_reports
  ADD COLUMN IF NOT EXISTS report_type TEXT DEFAULT 'standard_blood',
  ADD COLUMN IF NOT EXISTS provider_name TEXT,
  ADD COLUMN IF NOT EXISTS ai_interpretation TEXT,
  ADD COLUMN IF NOT EXISTS panel_metadata JSONB DEFAULT '{}'::jsonb;

-- 2. Backfill existing reports as standard_blood
UPDATE public.lab_reports
SET report_type = 'standard_blood'
WHERE report_type IS NULL;

-- 3. Create index on report_type for filtering
CREATE INDEX IF NOT EXISTS lab_reports_report_type_idx
  ON public.lab_reports(report_type);

-- 4. Verify (optional)
-- SELECT report_type, COUNT(*) FROM public.lab_reports GROUP BY report_type;
