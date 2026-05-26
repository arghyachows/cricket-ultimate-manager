-- ============================================================
-- Fix award_match_rewards RPC function
-- Returns old_level, new_level, and pack_awarded for level-up detection
-- ============================================================

CREATE OR REPLACE FUNCTION award_match_rewards(
    p_user_id UUID,
    p_coins INTEGER,
    p_xp INTEGER,
    p_won BOOLEAN
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_old_xp INTEGER;
    v_old_level INTEGER;
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_new_matches_played INTEGER;
    v_season_points_delta INTEGER;
    v_pack_awarded TEXT := NULL;
BEGIN
    -- Get current values
    SELECT xp, level, matches_played
    INTO v_old_xp, v_old_level, v_new_matches_played
    FROM users WHERE id = p_user_id;

    -- Calculate new values
    v_new_xp := v_old_xp + p_xp;
    v_new_level := LEAST(FLOOR(v_new_xp::numeric / 500) + 1, 100);
    v_new_matches_played := v_new_matches_played + 1;
    
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

    -- Grant level-up pack if user leveled up
    IF v_new_level > v_old_level THEN
        -- Determine pack name and probabilities based on new level
        v_pack_awarded := CASE
            WHEN v_new_level % 10 = 0 THEN 'Gold Pack'
            WHEN v_new_level % 5 = 0 THEN 'Silver Pack'
            ELSE 'Bronze Pack'
        END;

        -- Insert pack into user_card_packs with appropriate probabilities
        INSERT INTO user_card_packs (
            user_id, 
            pack_name, 
            card_count,
            bronze_chance,
            silver_chance,
            gold_chance,
            elite_chance,
            legend_chance,
            source
        )
        VALUES (
            p_user_id, 
            v_pack_awarded,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 5
                WHEN 'Silver Pack' THEN 4
                ELSE 3
            END,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 10
                WHEN 'Silver Pack' THEN 30
                ELSE 70
            END,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 25
                WHEN 'Silver Pack' THEN 45
                ELSE 22
            END,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 40
                WHEN 'Silver Pack' THEN 18
                ELSE 6
            END,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 18
                WHEN 'Silver Pack' THEN 5
                ELSE 1.5
            END,
            CASE v_pack_awarded
                WHEN 'Gold Pack' THEN 7
                WHEN 'Silver Pack' THEN 2
                ELSE 0.5
            END,
            'level_up_' || v_new_level::text
        );
    END IF;

    -- Return level info for client
    RETURN jsonb_build_object(
        'old_level', v_old_level,
        'new_level', v_new_level,
        'pack_awarded', v_pack_awarded
    );
END;
$$;
