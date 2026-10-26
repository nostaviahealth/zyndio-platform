-- =============================================
-- DAILY BIO LOGS TABLE
-- User-submitted daily vitals tracking
-- =============================================

CREATE TABLE IF NOT EXISTS public.daily_bio_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    sleep_quality TEXT CHECK (sleep_quality IN ('Poor', 'Fair', 'Good', 'Great')),
    stress_level INTEGER CHECK (stress_level >= 1 AND stress_level <= 5),
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 5),
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_bio_logs_patient_id_idx ON public.daily_bio_logs(patient_id);
CREATE INDEX IF NOT EXISTS daily_bio_logs_logged_at_idx ON public.daily_bio_logs(logged_at);

ALTER TABLE public.daily_bio_logs ENABLE ROW LEVEL SECURITY;

-- Users can insert their own bio logs
CREATE POLICY "Users can insert their own bio logs"
    ON public.daily_bio_logs FOR INSERT
    WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

-- Users can view their own bio logs
CREATE POLICY "Users can view their own bio logs"
    ON public.daily_bio_logs FOR SELECT
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

-- Admins can view all bio logs
CREATE POLICY "Admins can view all bio logs"
    ON public.daily_bio_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')
        )
    );

-- =============================================
-- DAILY JOURNALS TABLE
-- User-submitted daily journal entries
-- =============================================

CREATE TABLE IF NOT EXISTS public.daily_journals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS daily_journals_patient_id_idx ON public.daily_journals(patient_id);
CREATE INDEX IF NOT EXISTS daily_journals_logged_at_idx ON public.daily_journals(logged_at);

ALTER TABLE public.daily_journals ENABLE ROW LEVEL SECURITY;

-- Users can insert their own journal entries
CREATE POLICY "Users can insert their own journals"
    ON public.daily_journals FOR INSERT
    WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

-- Users can view their own journal entries
CREATE POLICY "Users can view their own journals"
    ON public.daily_journals FOR SELECT
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

-- Admins can view all journal entries
CREATE POLICY "Admins can view all journals"
    ON public.daily_journals FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'doctor', 'nutritionist')
        )
    );
