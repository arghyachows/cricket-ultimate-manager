-- ============================================================
-- Create award_match_rewards RPC function
-- Atomically updates coins, XP, level, and match stats
-- ============================================================

CREATE OR REPLACE FUNCTION award_match_rewards(
    p_user_id UUID,
    p_coins INTEGER,
    p_xp INTEGER,
    p_won BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_new_matches_played INTEGER;
    v_season_points_delta INTEGER;
BEGIN
    -- Calculate new XP and level
    SELECT xp + p_xp, matches_played + 1
    INTO v_new_xp, v_new_matches_played
    FROM users WHERE id = p_user_id;

    v_new_level := LEAST(FLOOR(v_new_xp::numeric / 500) + 1, 100);
    v_season_points_delta := CASE WHEN p_won
        THEN 100 + LEAST(v_new_level * 5, 200)
        ELSE 10 + LEAST(v_new_level, 50)
    END;

    -- Atomic update including season_points and matches_won
    UPDATE users SET
        coins = coins + p_coins,
        xp = v_new_xp,
        level = v_new_level,
        matches_played = v_new_matches_played,
        matches_won = CASE WHEN p_won THEN matches_won + 1 ELSE matches_won END,
        season_points = season_points + v_season_points_delta,
        updated_at = NOW()
    WHERE id = p_user_id;
END;
$$;

-- Also fix any existing users whose level is out of sync with XP
UPDATE users SET level = LEAST(FLOOR(xp::numeric / 500) + 1, 100)
WHERE level != LEAST(FLOOR(xp::numeric / 500) + 1, 100);
