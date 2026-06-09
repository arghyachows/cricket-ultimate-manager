-- ============================================================
-- CRICKET ULTIMATE MANAGER - Contract Market Support
-- Adds contract listing support to transfer_market
-- ============================================================

-- Add listing_type enum
CREATE TYPE listing_type AS ENUM ('card', 'contract');

-- Extend transfer_market for contract listings
ALTER TABLE transfer_market ADD COLUMN listing_type listing_type NOT NULL DEFAULT 'card';
ALTER TABLE transfer_market ADD COLUMN contract_type_id UUID REFERENCES contract_types(id);
ALTER TABLE transfer_market ADD COLUMN quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0 AND quantity <= 10);
ALTER TABLE transfer_market ALTER COLUMN user_card_id DROP NOT NULL;

-- Add contract_buy and contract_sell to transaction_type enum
ALTER TYPE transaction_type ADD VALUE 'contract_buy';
ALTER TYPE transaction_type ADD VALUE 'contract_sell';

-- Index for contract listings
CREATE INDEX idx_transfer_market_contract ON transfer_market(contract_type_id) WHERE listing_type = 'contract';

-- ============================================================
-- RPC FUNCTIONS FOR CONTRACT MARKET
-- ============================================================

-- List a contract for sale
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
        user_card_id, -- nullable for contract listings, use a dummy or make nullable
        buy_now_price,
        starting_bid,
        status,
        expires_at,
        listing_type,
        contract_type_id,
        quantity
    ) VALUES (
        p_seller_id,
        NULL, -- no user_card_id for contracts
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

-- Buy a contract from market (buy now only, no bidding for contracts)
CREATE OR REPLACE FUNCTION buy_contract_from_market(
    p_listing_id UUID,
    p_buyer_id UUID,
    p_quantity INT DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_buyer_coins INT;
    v_total_price INT;
    v_tax INT;
    v_seller_receives INT;
    v_contract_type contract_types%ROWTYPE;
BEGIN
    -- Lock listing
    SELECT * INTO v_listing
    FROM transfer_market
    WHERE id = p_listing_id
    FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;

    IF v_listing.listing_type != 'contract' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a contract listing');
    END IF;

    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing is no longer active');
    END IF;

    IF v_listing.expires_at < NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing has expired');
    END IF;

    IF v_listing.seller_id = p_buyer_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot buy your own listing');
    END IF;

    IF p_quantity < 1 OR p_quantity > v_listing.quantity THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;

    -- Calculate price (price_per_unit * quantity)
    v_total_price := (v_listing.buy_now_price / v_listing.quantity) * p_quantity;

    -- Check buyer coins
    SELECT coins INTO v_buyer_coins FROM users WHERE id = p_buyer_id FOR UPDATE;
    IF v_buyer_coins < v_total_price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough coins');
    END IF;

    -- Get contract type info
    SELECT * INTO v_contract_type
    FROM contract_types
    WHERE id = v_listing.contract_type_id;

    -- Calculate tax (5%)
    v_tax := GREATEST(FLOOR(v_total_price * 0.05), 1);
    v_seller_receives := v_total_price - v_tax;

    -- Deduct from buyer
    UPDATE users SET coins = coins - v_total_price WHERE id = p_buyer_id;

    -- Credit seller
    UPDATE users SET coins = coins + v_seller_receives WHERE id = v_listing.seller_id;

    -- Add contracts to buyer's inventory
    PERFORM upsert_user_contract(p_buyer_id, v_listing.contract_type_id, p_quantity, 'market');

    -- Update listing quantity or mark as sold
    IF p_quantity >= v_listing.quantity THEN
        UPDATE transfer_market SET status = 'sold', sold_at = NOW() WHERE id = p_listing_id;
    ELSE
        UPDATE transfer_market SET quantity = quantity - p_quantity WHERE id = p_listing_id;
    END IF;

    -- Log transactions
    INSERT INTO transactions (user_id, type, coins_amount, description)
    VALUES
        (p_buyer_id, 'contract_buy', -v_total_price, 'Bought ' || v_contract_type.name || ' x' || p_quantity || ' from market'),
        (v_listing.seller_id, 'contract_sell', v_seller_receives, 'Sold ' || v_contract_type.name || ' x' || p_quantity || ' on market (5% tax)');

    RETURN jsonb_build_object('success', true, 'message', 'Contract purchased successfully');
END;
$$;

-- Cancel a contract listing (seller only)
CREATE OR REPLACE FUNCTION cancel_contract_listing(
    p_listing_id UUID,
    p_seller_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_contract_type contract_types%ROWTYPE;
BEGIN
    SELECT * INTO v_listing
    FROM transfer_market
    WHERE id = p_listing_id
    FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;

    IF v_listing.listing_type != 'contract' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a contract listing');
    END IF;

    IF v_listing.seller_id != p_seller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not your listing');
    END IF;

    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing is not active');
    END IF;

    -- Get contract type
    SELECT * INTO v_contract_type
    FROM contract_types
    WHERE id = v_listing.contract_type_id;

    -- Return contracts to seller
    PERFORM upsert_user_contract(p_seller_id, v_listing.contract_type_id, v_listing.quantity, 'market');

    UPDATE transfer_market SET status = 'cancelled' WHERE id = p_listing_id;

    RETURN jsonb_build_object('success', true, 'message', 'Listing cancelled, contracts returned');
END;
$$;

-- Settle expired contract listing
CREATE OR REPLACE FUNCTION settle_expired_contract_listing(
    p_listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_contract_type contract_types%ROWTYPE;
BEGIN
    SELECT * INTO v_listing
    FROM transfer_market
    WHERE id = p_listing_id
    FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;

    IF v_listing.listing_type != 'contract' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a contract listing');
    END IF;

    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing already settled');
    END IF;

    IF v_listing.expires_at > NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing has not expired yet');
    END IF;

    -- Get contract type
    SELECT * INTO v_contract_type
    FROM contract_types
    WHERE id = v_listing.contract_type_id;

    -- Return contracts to seller
    PERFORM upsert_user_contract(v_listing.seller_id, v_listing.contract_type_id, v_listing.quantity, 'market');

    UPDATE transfer_market SET status = 'expired' WHERE id = p_listing_id;

    RETURN jsonb_build_object('success', true, 'message', 'Listing expired, contracts returned to seller');
END;
$$;
