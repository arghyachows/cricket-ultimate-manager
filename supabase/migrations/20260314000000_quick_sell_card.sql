-- ============================================================
-- RPC: update_user_coins (was missing from initial schema)
-- ============================================================
CREATE OR REPLACE FUNCTION update_user_coins(p_user_id UUID, p_amount INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE users SET coins = coins + p_amount WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: quick_sell_card
-- Atomically removes a user card and credits coins
-- Handles all FK references safely
-- ============================================================
CREATE OR REPLACE FUNCTION quick_sell_card(p_user_card_id UUID, p_sell_price INTEGER)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Verify ownership
    SELECT user_id INTO v_user_id
    FROM user_cards
    WHERE id = p_user_card_id;

    IF v_user_id IS NULL OR v_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Card not found or not owned by user';
    END IF;

    -- Remove from any squad
    DELETE FROM squad_players WHERE user_card_id = p_user_card_id;

    -- Remove from transfer market
    DELETE FROM transfer_market WHERE user_card_id = p_user_card_id;

    -- Nullify nullable match references
    UPDATE matches SET man_of_match = NULL WHERE man_of_match = p_user_card_id;
    UPDATE match_events SET fielder_card_id = NULL WHERE fielder_card_id = p_user_card_id;

    -- Remove match events where this card was batsman or bowler (NOT NULL columns)
    DELETE FROM match_events WHERE batsman_card_id = p_user_card_id OR bowler_card_id = p_user_card_id;

    -- Delete the card
    DELETE FROM user_cards WHERE id = p_user_card_id AND user_id = v_user_id;

    -- Credit coins
    UPDATE users SET coins = coins + p_sell_price WHERE id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
