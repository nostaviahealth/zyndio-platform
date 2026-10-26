-- =============================================
-- FIX LEAGUE XP — Add missing columns and update RPC
-- =============================================

-- 1. Add missing league columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS league_xp INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS current_league TEXT DEFAULT 'bronze' NOT NULL,
ADD COLUMN IF NOT EXISTS league_reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
ADD COLUMN IF NOT EXISTS league_badges JSONB DEFAULT '{}'::jsonb NOT NULL;

-- 2. Update award_reward RPC to increment both lifetime XP and monthly League XP
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
    v_new_league_xp INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Try to insert log. Unique constraint prevents duplicates.
    BEGIN
        INSERT INTO public.reward_logs (user_id, reward_type, xp_amount, coins_amount, reference_id)
        VALUES (p_user_id, p_reward_type, p_xp_amount, p_coins_amount, p_reference_id);
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'message', 'Already claimed');
    END;

    -- Atomically increment lifetime XP, monthly league_xp, and Coins
    UPDATE public.profiles
    SET
        xp = xp + p_xp_amount,
        league_xp = league_xp + p_xp_amount,
        coins = coins + p_coins_amount,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING xp, league_xp, coins INTO v_new_xp, v_new_league_xp, v_new_coins;

    RETURN jsonb_build_object(
        'success', true,
        'xp_earned', p_xp_amount,
        'coins_earned', p_coins_amount,
        'total_xp', v_new_xp,
        'league_xp', v_new_league_xp,
        'total_coins', v_new_coins
    );
END;
$$;
