-- Level-Up Card Pack Rewards
-- Automatically grants a card pack when a user levels up after a match.
-- Pack tier scales with the new level:
--   1-10  → Bronze Pack  (3 cards, bronze-heavy)
--   11-25 → Silver Pack  (5 cards, silver-heavy)
--   26-45 → Gold Pack    (5 cards, gold-heavy)
--   46-65 → Elite Pack   (7 cards, elite-heavy)
--   66+   → Legend Pack  (7 cards, legend-heavy)

-- Drop old function first (return type changed from void → jsonb)
DROP FUNCTION IF EXISTS award_match_rewards(uuid, integer, integer, boolean);

-- Recreate with level-up pack granting
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
    v_pack_name TEXT;
    v_card_count INTEGER;
    v_bronze DOUBLE PRECISION;
    v_silver DOUBLE PRECISION;
    v_gold DOUBLE PRECISION;
    v_elite DOUBLE PRECISION;
    v_legend DOUBLE PRECISION;
BEGIN
    -- Get current XP and level
    SELECT xp, level INTO v_old_xp, v_old_level FROM users WHERE id = p_user_id;

    -- Calculate new XP and level
    v_new_xp := v_old_xp + p_xp;
    v_new_level := LEAST(FLOOR(v_new_xp::numeric / 500) + 1, 100);

    -- Atomic update
    UPDATE users SET
        coins = coins + p_coins,
        xp = v_new_xp,
        level = v_new_level,
        matches_played = matches_played + 1,
        matches_won = CASE WHEN p_won THEN matches_won + 1 ELSE matches_won END,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Check for level-up
    IF v_new_level > v_old_level THEN
        -- Determine pack tier based on new level
        IF v_new_level <= 10 THEN
            v_pack_name := 'Bronze Pack';
            v_card_count := 3;
            v_bronze := 60; v_silver := 25; v_gold := 10; v_elite := 4; v_legend := 1;
        ELSIF v_new_level <= 25 THEN
            v_pack_name := 'Silver Pack';
            v_card_count := 5;
            v_bronze := 20; v_silver := 45; v_gold := 25; v_elite := 8; v_legend := 2;
        ELSIF v_new_level <= 45 THEN
            v_pack_name := 'Gold Pack';
            v_card_count := 5;
            v_bronze := 5; v_silver := 20; v_gold := 45; v_elite := 22; v_legend := 8;
        ELSIF v_new_level <= 65 THEN
            v_pack_name := 'Elite Pack';
            v_card_count := 7;
            v_bronze := 0; v_silver := 10; v_gold := 25; v_elite := 45; v_legend := 20;
        ELSE
            v_pack_name := 'Legend Pack';
            v_card_count := 7;
            v_bronze := 0; v_silver := 0; v_gold := 15; v_elite := 35; v_legend := 50;
        END IF;

        -- Grant the pack
        INSERT INTO user_card_packs (
            user_id, pack_name, card_count,
            bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance,
            source
        ) VALUES (
            p_user_id, v_pack_name, v_card_count,
            v_bronze, v_silver, v_gold, v_elite, v_legend,
            'reward'
        );

        RETURN jsonb_build_object(
            'old_level', v_old_level,
            'new_level', v_new_level,
            'pack_awarded', v_pack_name
        );
    END IF;

    RETURN jsonb_build_object(
        'old_level', v_old_level,
        'new_level', v_new_level,
        'pack_awarded', NULL
    );
END;
$$;
