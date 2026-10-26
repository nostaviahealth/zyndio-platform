-- =============================================
-- LEAGUE SYSTEM — Monthly Resets & Badges
-- =============================================

-- 1. Add League columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS league_xp INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS current_league TEXT DEFAULT 'bronze' NOT NULL,
ADD COLUMN IF NOT EXISTS league_reset_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
ADD COLUMN IF NOT EXISTS league_badges JSONB DEFAULT '{}'::jsonb NOT NULL;

-- 2. Update award_reward to handle league_xp
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
    v_new_league_xp INTEGER;
BEGIN
    -- Try to insert log. Unique constraint prevents duplicates.
    BEGIN
        INSERT INTO public.reward_logs (user_id, reward_type, xp_amount, coins_amount, reference_id)
        VALUES (p_user_id, p_reward_type, p_xp_amount, p_coins_amount, p_reference_id);
    EXCEPTION WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'message', 'Already claimed');
    END;

    -- Atomically increment XP, Coins, and League XP on the profile
    UPDATE public.profiles
    SET
        xp = xp + p_xp_amount,
        league_xp = league_xp + p_xp_amount,
        coins = coins + p_coins_amount,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING xp, coins, league_xp INTO v_new_xp, v_new_coins, v_new_league_xp;

    RETURN jsonb_build_object(
        'success', true,
        'xp_earned', p_xp_amount,
        'coins_earned', p_coins_amount,
        'total_xp', v_new_xp,
        'total_coins', v_new_coins,
        'league_xp', v_new_league_xp
    );
END;
$$;

-- 3. Reset League function — awards badge and resets league_xp
CREATE OR REPLACE FUNCTION public.reset_league(
    p_user_id UUID,
    p_next_reset TIMESTAMP WITH TIME ZONE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_league TEXT;
    v_badges JSONB;
    v_count INTEGER;
BEGIN
    -- Get current status
    SELECT current_league, league_badges INTO v_current_league, v_badges
    FROM public.profiles
    WHERE user_id = p_user_id;

    -- Award badge if Silver or above
    IF v_current_league != 'bronze' THEN
        v_count := (v_badges->>v_current_league)::INTEGER;
        IF v_count IS NULL THEN
            v_count := 1;
        ELSE
            v_count := v_count + 1;
        END IF;
        v_badges := v_badges || jsonb_build_object(v_current_league, v_count);
    END IF;

    -- Reset
    UPDATE public.profiles
    SET
        league_xp = 0,
        current_league = 'bronze',
        league_reset_at = p_next_reset,
        league_badges = v_badges,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_badges', v_badges,
        'reset_at', p_next_reset
    );
END;
$$;
