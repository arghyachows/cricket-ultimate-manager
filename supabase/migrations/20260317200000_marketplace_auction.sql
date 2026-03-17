-- ============================================================
-- Fully Functional Marketplace Auction System
-- - Bid history table
-- - Place bid RPC (escrow coins, outbid refund)
-- - Buy-now RPC (instant purchase)
-- - Settle expired auction RPC (award to highest bidder)
-- - Cancel listing RPC
-- ============================================================

-- 1) Bid history table
CREATE TABLE IF NOT EXISTS market_bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES transfer_market(id) ON DELETE CASCADE,
    bidder_id UUID NOT NULL REFERENCES users(id),
    bid_amount INTEGER NOT NULL CHECK (bid_amount > 0),
    status TEXT NOT NULL DEFAULT 'active',  -- 'active', 'outbid', 'won', 'lost'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_market_bids_listing ON market_bids(listing_id);
CREATE INDEX IF NOT EXISTS idx_market_bids_bidder ON market_bids(bidder_id, status);

ALTER TABLE market_bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view bids" ON market_bids FOR SELECT USING (true);
CREATE POLICY "Users can insert own bids" ON market_bids FOR INSERT WITH CHECK (auth.uid() = bidder_id);

-- Allow service role and RPC functions to manage bids
CREATE POLICY "Service can manage bids" ON market_bids FOR ALL USING (true);

-- 2) Fix RLS on transfer_market: allow any authenticated user to update (for bids)
DROP POLICY IF EXISTS "Sellers can manage own listings" ON transfer_market;
CREATE POLICY "Authenticated users can insert listings" ON transfer_market
    FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Authenticated users can update listings" ON transfer_market
    FOR UPDATE USING (true);
CREATE POLICY "Sellers can delete own listings" ON transfer_market
    FOR DELETE USING (auth.uid() = seller_id);

-- 3) Place Bid RPC
-- Validates: listing active, not expired, not own listing, bid > current_bid & >= starting_bid,
-- user has enough coins. Escrows coins (deducts from bidder), refunds previous bidder.
CREATE OR REPLACE FUNCTION place_market_bid(
    p_listing_id UUID,
    p_bidder_id UUID,
    p_bid_amount INTEGER
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_bidder_coins INTEGER;
    v_prev_bidder_id UUID;
    v_prev_bid INTEGER;
BEGIN
    -- Lock the listing row
    SELECT * INTO v_listing FROM transfer_market WHERE id = p_listing_id FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;

    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing is no longer active');
    END IF;

    IF v_listing.expires_at < NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing has expired');
    END IF;

    IF v_listing.seller_id = p_bidder_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot bid on your own listing');
    END IF;

    IF p_bid_amount < v_listing.starting_bid THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bid must be at least the starting bid');
    END IF;

    IF p_bid_amount <= v_listing.current_bid THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bid must be higher than current bid');
    END IF;

    -- Check bidder has enough coins
    SELECT coins INTO v_bidder_coins FROM users WHERE id = p_bidder_id FOR UPDATE;
    IF v_bidder_coins < p_bid_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough coins');
    END IF;

    -- Store previous bidder info for refund
    v_prev_bidder_id := v_listing.current_bidder_id;
    v_prev_bid := v_listing.current_bid;

    -- Deduct coins from new bidder (escrow)
    UPDATE users SET coins = coins - p_bid_amount WHERE id = p_bidder_id;

    -- Refund previous bidder if exists
    IF v_prev_bidder_id IS NOT NULL AND v_prev_bid > 0 THEN
        UPDATE users SET coins = coins + v_prev_bid WHERE id = v_prev_bidder_id;
        -- Mark previous bid as outbid
        UPDATE market_bids SET status = 'outbid'
            WHERE listing_id = p_listing_id AND bidder_id = v_prev_bidder_id AND status = 'active';
    END IF;

    -- Update listing with new bid
    UPDATE transfer_market SET
        current_bid = p_bid_amount,
        current_bidder_id = p_bidder_id
    WHERE id = p_listing_id;

    -- Insert bid record
    INSERT INTO market_bids (listing_id, bidder_id, bid_amount, status)
    VALUES (p_listing_id, p_bidder_id, p_bid_amount, 'active');

    RETURN jsonb_build_object('success', true, 'message', 'Bid placed successfully');
END;
$$;

-- 4) Buy Now RPC
-- Instant purchase at buy_now_price. Transfers card, deducts coins (with tax), credits seller.
DROP FUNCTION IF EXISTS execute_market_purchase(UUID, UUID);
CREATE OR REPLACE FUNCTION execute_market_purchase(
    p_listing_id UUID,
    p_buyer_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_buyer_coins INTEGER;
    v_price INTEGER;
    v_tax INTEGER;
    v_seller_receives INTEGER;
    v_prev_bidder_id UUID;
    v_prev_bid INTEGER;
BEGIN
    -- Lock listing
    SELECT * INTO v_listing FROM transfer_market WHERE id = p_listing_id FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;
    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing is no longer active');
    END IF;
    IF v_listing.seller_id = p_buyer_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot buy your own listing');
    END IF;

    v_price := v_listing.buy_now_price;

    -- Check buyer coins
    SELECT coins INTO v_buyer_coins FROM users WHERE id = p_buyer_id FOR UPDATE;
    IF v_buyer_coins < v_price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough coins');
    END IF;

    -- Refund the current highest bidder (their coins are escrowed)
    v_prev_bidder_id := v_listing.current_bidder_id;
    v_prev_bid := v_listing.current_bid;
    IF v_prev_bidder_id IS NOT NULL AND v_prev_bid > 0 THEN
        UPDATE users SET coins = coins + v_prev_bid WHERE id = v_prev_bidder_id;
        UPDATE market_bids SET status = 'lost'
            WHERE listing_id = p_listing_id AND bidder_id = v_prev_bidder_id AND status = 'active';
    END IF;

    -- Calculate tax (5%)
    v_tax := GREATEST(FLOOR(v_price * 0.05), 1);
    v_seller_receives := v_price - v_tax;

    -- Deduct from buyer
    UPDATE users SET coins = coins - v_price WHERE id = p_buyer_id;

    -- Credit seller
    UPDATE users SET coins = coins + v_seller_receives WHERE id = v_listing.seller_id;

    -- Transfer card ownership
    UPDATE user_cards SET user_id = p_buyer_id, is_tradeable = true WHERE id = v_listing.user_card_id;

    -- Remove from seller's squad if present
    DELETE FROM squad_players WHERE user_card_id = v_listing.user_card_id;

    -- Mark listing as sold
    UPDATE transfer_market SET status = 'sold', sold_at = NOW(), current_bidder_id = p_buyer_id
        WHERE id = p_listing_id;

    -- Mark all other bids as lost
    UPDATE market_bids SET status = 'lost'
        WHERE listing_id = p_listing_id AND status IN ('active', 'outbid');

    -- Log transactions
    INSERT INTO transactions (user_id, type, coins_amount, description)
    VALUES
        (p_buyer_id, 'market_buy', -v_price, 'Bought card from market'),
        (v_listing.seller_id, 'market_sell', v_seller_receives, 'Sold card on market (5% tax)');

    RETURN jsonb_build_object('success', true, 'message', 'Purchase successful');
END;
$$;

-- 5) Settle Expired Auction RPC
-- Awards card to highest bidder when auction expires. If no bids, marks as expired.
CREATE OR REPLACE FUNCTION settle_expired_auction(p_listing_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
    v_tax INTEGER;
    v_seller_receives INTEGER;
BEGIN
    SELECT * INTO v_listing FROM transfer_market WHERE id = p_listing_id FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;
    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing already settled');
    END IF;
    IF v_listing.expires_at > NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing has not expired yet');
    END IF;

    -- No bids → mark expired, card returns to seller
    IF v_listing.current_bidder_id IS NULL OR v_listing.current_bid <= 0 THEN
        UPDATE transfer_market SET status = 'expired' WHERE id = p_listing_id;
        -- Restore tradeable flag for seller
        UPDATE user_cards SET is_tradeable = true WHERE id = v_listing.user_card_id;
        RETURN jsonb_build_object('success', true, 'message', 'No bids — listing expired');
    END IF;

    -- Award to highest bidder (coins already escrowed when bid was placed)
    v_tax := GREATEST(FLOOR(v_listing.current_bid * 0.05), 1);
    v_seller_receives := v_listing.current_bid - v_tax;

    -- Credit seller
    UPDATE users SET coins = coins + v_seller_receives WHERE id = v_listing.seller_id;

    -- Transfer card to winner
    UPDATE user_cards SET user_id = v_listing.current_bidder_id, is_tradeable = true
        WHERE id = v_listing.user_card_id;

    -- Remove from seller's squad
    DELETE FROM squad_players WHERE user_card_id = v_listing.user_card_id;

    -- Mark listing as sold
    UPDATE transfer_market SET status = 'sold', sold_at = NOW() WHERE id = p_listing_id;

    -- Update bids
    UPDATE market_bids SET status = 'won'
        WHERE listing_id = p_listing_id AND bidder_id = v_listing.current_bidder_id AND status = 'active';
    UPDATE market_bids SET status = 'lost'
        WHERE listing_id = p_listing_id AND status IN ('active', 'outbid');

    -- Log transactions
    INSERT INTO transactions (user_id, type, coins_amount, description)
    VALUES
        (v_listing.current_bidder_id, 'market_buy', -v_listing.current_bid, 'Won auction bid'),
        (v_listing.seller_id, 'market_sell', v_seller_receives, 'Auction sold (5% tax)');

    RETURN jsonb_build_object('success', true, 'message', 'Auction settled — card awarded to highest bidder');
END;
$$;

-- 6) Cancel Listing RPC (seller only, refunds current bidder)
CREATE OR REPLACE FUNCTION cancel_market_listing(p_listing_id UUID, p_seller_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_listing transfer_market%ROWTYPE;
BEGIN
    SELECT * INTO v_listing FROM transfer_market WHERE id = p_listing_id FOR UPDATE;

    IF v_listing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found');
    END IF;
    IF v_listing.seller_id != p_seller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not your listing');
    END IF;
    IF v_listing.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing is not active');
    END IF;

    -- Refund current bidder if any
    IF v_listing.current_bidder_id IS NOT NULL AND v_listing.current_bid > 0 THEN
        UPDATE users SET coins = coins + v_listing.current_bid WHERE id = v_listing.current_bidder_id;
        UPDATE market_bids SET status = 'lost'
            WHERE listing_id = p_listing_id AND status = 'active';
    END IF;

    UPDATE transfer_market SET status = 'cancelled' WHERE id = p_listing_id;

    -- Restore tradeable flag for seller
    UPDATE user_cards SET is_tradeable = true WHERE id = v_listing.user_card_id;

    RETURN jsonb_build_object('success', true, 'message', 'Listing cancelled');
END;
$$;
