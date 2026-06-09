-- ============================================================
-- CRICKET ULTIMATE MANAGER - Contract Consumption on Match Completion
-- Atomic RPC to decrement contracts_remaining for each user XI player
-- Uses idempotency pattern to prevent double-spending on retry
-- ============================================================

-- Consume contracts for user's playing XI after match completion
-- Only consumes for the user's team (home or away), not AI opponent
-- Returns JSON with details of which contracts were consumed
CREATE OR REPLACE FUNCTION consume_contracts_on_match_completion(
    p_user_id UUID,
    p_match_id UUID,
    p_user_card_ids UUID[],
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
    v_consumed JSONB := '[]'::jsonb;
    v_errors JSONB := '[]'::jsonb;
    v_card_id UUID;
    v_contracts_before INT;
    v_contracts_after INT;
    v_idempotency_result JSONB;
BEGIN
    -- Idempotency check: if key provided and exists, return cached result
    IF p_idempotency_key IS NOT NULL THEN
        SELECT result INTO v_idempotency_result
        FROM idempotency_keys
        WHERE idempotency_key = p_idempotency_key
          AND user_id = p_user_id
          AND operation = 'consume_contracts'
          AND expires_at > NOW();
        
        IF v_idempotency_result IS NOT NULL THEN
            RETURN v_idempotency_result;
        END IF;
    END IF;

    -- Verify match exists and belongs to user (home or away)
    -- Check both 'matches' (single-player) and 'multiplayer_matches' tables
    PERFORM 1 FROM matches
    WHERE id = p_match_id
      AND (home_user_id = p_user_id OR away_user_id = p_user_id);
    
    IF NOT FOUND THEN
        PERFORM 1 FROM multiplayer_matches
        WHERE id = p_match_id
          AND (home_user_id = p_user_id OR away_user_id = p_user_id);
    END IF;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Match not found or user not a participant';
    END IF;

    -- Check if contracts already consumed for this match
    PERFORM 1 FROM match_contract_consumption
    WHERE match_id = p_match_id AND user_id = p_user_id;
    
    IF FOUND THEN
        -- Already consumed, return existing result
        SELECT result INTO v_result FROM match_contract_consumption
        WHERE match_id = p_match_id AND user_id = p_user_id;
        
        -- Store in idempotency table if key provided
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (idempotency_key, user_id, operation, result, expires_at)
            VALUES (p_idempotency_key, p_user_id, 'consume_contracts', v_result, NOW() + INTERVAL '24 hours')
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
        
        RETURN v_result;
    END IF;

    -- Process each user card in the XI
    FOREACH v_card_id IN ARRAY p_user_card_ids LOOP
        -- Get current contracts for this card
        SELECT contracts_remaining INTO v_contracts_before
        FROM user_cards
        WHERE id = v_card_id AND user_id = p_user_id;
        
        IF NOT FOUND THEN
            v_errors := v_errors || jsonb_build_object(
                'user_card_id', v_card_id,
                'error', 'Card not found or not owned by user'
            );
            CONTINUE;
        END IF;
        
        -- Only consume if contracts > 0 (should not happen if validated pre-match)
        IF v_contracts_before <= 0 THEN
            v_errors := v_errors || jsonb_build_object(
                'user_card_id', v_card_id,
                'error', 'Player already out of contracts'
            );
            CONTINUE;
        END IF;
        
        -- Decrement contracts_remaining by 1
        UPDATE user_cards
        SET contracts_remaining = contracts_remaining - 1,
            matches_played = matches_played + 1
        WHERE id = v_card_id AND user_id = p_user_id
        RETURNING contracts_remaining INTO v_contracts_after;
        
        v_consumed := v_consumed || jsonb_build_object(
            'user_card_id', v_card_id,
            'contracts_before', v_contracts_before,
            'contracts_after', v_contracts_after,
            'is_out_of_contracts', v_contracts_after = 0
        );
    END LOOP;

    -- Build final result
    v_result := jsonb_build_object(
        'success', true,
        'consumed', v_consumed,
        'errors', v_errors,
        'total_consumed', jsonb_array_length(v_consumed),
        'total_errors', jsonb_array_length(v_errors)
    );

    -- Record consumption for audit/idempotency
    INSERT INTO match_contract_consumption (match_id, user_id, user_card_ids, result)
    VALUES (p_match_id, p_user_id, p_user_card_ids, v_result);

    -- Store in idempotency table if key provided
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (idempotency_key, user_id, operation, result, expires_at)
        VALUES (p_idempotency_key, p_user_id, 'consume_contracts', v_result, NOW() + INTERVAL '24 hours')
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    RETURN v_result;
END;
$$;

-- Audit table for contract consumption per match
CREATE TABLE IF NOT EXISTS match_contract_consumption (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_card_ids UUID[] NOT NULL,
    result JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_match_contract_consumption_match ON match_contract_consumption(match_id);
CREATE INDEX IF NOT EXISTS idx_match_contract_consumption_user ON match_contract_consumption(user_id);

-- Add to idempotency_keys operation check constraint
ALTER TABLE idempotency_keys 
DROP CONSTRAINT IF EXISTS idempotency_keys_operation_check;

ALTER TABLE idempotency_keys
ADD CONSTRAINT idempotency_keys_operation_check 
CHECK (operation IN (
    'start_match',
    'confirm_match',
    'cancel_match',
    'complete_match',
    'consume_contracts'
));