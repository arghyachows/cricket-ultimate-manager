-- ============================================================
-- CRICKET ULTIMATE MANAGER - Contract Tradeable Tier Restriction
-- Only Gold, Elite, and Legend tier contracts can be listed on the market
-- ============================================================

-- Recreate list_contract_on_market with Gold+ tier check
CREATE OR REPLACE FUNCTION list_contract_on_market(
    p_seller_id UUID,
    p_contract_type_id UUID,
    p_quantity INT,
    p_price_per_unit INT,
    p_duration_hours INT DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_contract_type contract_types%ROWTYPE;
    v_user_contract user_contracts%ROWTYPE;
    v_min_price INT;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- Validate contract type exists and is available
    SELECT * INTO v_contract_type
    FROM contract_types
    WHERE id = p_contract_type_id AND is_available = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Contract type not found');
    END IF;

    -- Only Gold, Elite, and Legend tier contracts are tradeable
    IF v_contract_type.tier NOT IN ('gold', 'elite', 'legend') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only Gold, Elite, and Legend tier contracts can be traded on the market');
    END IF;

    -- Check user has enough contracts of this type (sum across all sources)
    SELECT SUM(quantity) INTO v_user_contract.quantity
    FROM user_contracts
    WHERE user_id = p_seller_id AND contract_type_id = p_contract_type_id AND quantity > 0;

    IF v_user_contract.quantity IS NULL OR v_user_contract.quantity < p_quantity THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough contracts to list');
    END IF;

    -- Validate price floor per tier
    CASE v_contract_type.tier
        WHEN 'bronze' THEN v_min_price := 10;
        WHEN 'silver' THEN v_min_price := 50;
        WHEN 'gold' THEN v_min_price := 200;
        WHEN 'elite' THEN v_min_price := 1000;
        WHEN 'legend' THEN v_min_price := 5000;
        ELSE v_min_price := 10;
    END CASE;

    IF p_price_per_unit < v_min_price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Price below minimum for ' || v_contract_type.tier || ' tier (' || v_min_price || ' coins)');
    END IF;

    IF p_quantity < 1 OR p_quantity > 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Quantity must be between 1 and 10');
    END IF;

    -- Deduct contracts from user inventory
    UPDATE user_contracts
    SET quantity = quantity - p_quantity
    WHERE user_id = p_seller_id AND contract_type_id = p_contract_type_id AND quantity > 0;

    -- Clean up zero quantity rows
    DELETE FROM user_contracts
    WHERE user_id = p_seller_id AND contract_type_id = p_contract_type_id AND quantity <= 0;

    v_expires_at := NOW() + (p_duration_hours || ' hours')::interval;

    -- Insert listing
    INSERT INTO transfer_market (
        seller_id,
        user_card_id,
        buy_now_price,
        starting_bid,
        status,
        expires_at,
        listing_type,
        contract_type_id,
        quantity
    ) VALUES (
        p_seller_id,
        NULL,
        p_price_per_unit * p_quantity,
        p_price_per_unit * p_quantity,
        'active',
        v_expires_at,
        'contract',
        p_contract_type_id,
        p_quantity
    );

    RETURN jsonb_build_object('success', true, 'message', 'Contract listed for sale');
END;
$$;
