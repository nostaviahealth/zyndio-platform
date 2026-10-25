-- =============================================
-- GAMIFICATION SYSTEM — XP & Coins
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. Add XP and Coins columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS coins INTEGER DEFAULT 0 NOT NULL;

-- 2. Reward Logs — audit trail + duplicate prevention
CREATE TABLE IF NOT EXISTS public.reward_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    reward_type TEXT NOT NULL,
    xp_amount INTEGER NOT NULL DEFAULT 0,
    coins_amount INTEGER NOT NULL DEFAULT 0,
    reference_id TEXT,  -- e.g. task_id, date string, scan timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

    -- Prevent same user from claiming same reward twice
    UNIQUE(user_id, reward_type, reference_id)
);

CREATE INDEX IF NOT EXISTS reward_logs_user_id_idx ON public.reward_logs(user_id);

ALTER TABLE public.reward_logs ENABLE ROW LEVEL SECURITY;

-- RLS: Users can only see their own rewards
CREATE POLICY "Users can view their own reward logs"
    ON public.reward_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reward logs"
    ON public.reward_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 3. Atomic reward function — handles insert + update in one call
CREATE OR REPLACE FUNCTION public.award_reward(
    p_user_id UUID,
    p_reward_type TEXT,
    p_xp_amount INTEGER,
    p_coins_amount INTEGER,
    p_reference_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_xp INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Try to insert log. Unique constraint prevents duplicates.
    BEGIN
        INSERT INTO public.reward_logs (user_id, reward_type, xp_amount, coins_amount, reference_id)
        VALUES (p_user_id, p_reward_type, p_xp_amount, p_coins_amount, p_reference_id);
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'message', 'Already claimed');
    END;

    -- Atomically increment XP and Coins on the profile
    UPDATE public.profiles
    SET
        xp = xp + p_xp_amount,
        coins = coins + p_coins_amount,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING xp, coins INTO v_new_xp, v_new_coins;

    RETURN jsonb_build_object(
        'success', true,
        'xp_earned', p_xp_amount,
        'coins_earned', p_coins_amount,
        'total_xp', v_new_xp,
        'total_coins', v_new_coins
    );
END;
$$;
