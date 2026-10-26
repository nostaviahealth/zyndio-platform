-- Add missing 'source' column to daily_rhythms table
-- This is required by RhythmNotifier for storing optimization metadata.

ALTER TABLE public.daily_rhythms 
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'generated';

-- Optional: Index for filtering by source if needed
CREATE INDEX IF NOT EXISTS daily_rhythms_source_idx ON public.daily_rhythms(source);
