-- ============================================================
-- CRICKET ULTIMATE MANAGER - Contracts System Migration
-- Adds contract_types, user_contracts, user_contract_packs tables
-- Adds contracts_remaining and contracts_max to user_cards
-- ============================================================

-- New table: contract_types (seed data like pack_types)
CREATE TABLE contract_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    tier TEXT NOT NULL CHECK (tier IN ('bronze', 'silver', 'gold', 'elite', 'legend')),
    matches_awarded INT NOT NULL CHECK (matches_awarded > 0),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- New table: user_contracts (quantity for stacking duplicates)
CREATE TABLE user_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contract_type_id UUID NOT NULL REFERENCES contract_types(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    source TEXT NOT NULL CHECK (source IN ('reward', 'purchase', 'tournament', 'market', 'pack')),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, contract_type_id, source)
);

-- New table: user_contract_packs (mirrors pack_types but for contract packs per user)
CREATE TABLE user_contract_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pack_name TEXT NOT NULL,
    contract_count INT NOT NULL DEFAULT 3 CHECK (contract_count > 0),
    bronze_chance NUMERIC(5,2) NOT NULL DEFAULT 60.00 CHECK (bronze_chance >= 0 AND bronze_chance <= 100),
    silver_chance NUMERIC(5,2) NOT NULL DEFAULT 25.00 CHECK (silver_chance >= 0 AND silver_chance <= 100),
    gold_chance NUMERIC(5,2) NOT NULL DEFAULT 10.00 CHECK (gold_chance >= 0 AND gold_chance <= 100),
    elite_chance NUMERIC(5,2) NOT NULL DEFAULT 4.00 CHECK (elite_chance >= 0 AND elite_chance <= 100),
    legend_chance NUMERIC(5,2) NOT NULL DEFAULT 1.00 CHECK (legend_chance >= 0 AND legend_chance <= 100),
    source TEXT NOT NULL CHECK (source IN ('reward', 'purchase', 'tournament', 'level_up')),
    opened BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ALTER TABLE user_cards ADD contracts columns
ALTER TABLE user_cards ADD COLUMN contracts_remaining INT NOT NULL DEFAULT 7;
ALTER TABLE user_cards ADD COLUMN contracts_max INT NOT NULL DEFAULT 7;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Contract types: Bronze (+3), Silver (+7), Gold (+15), Elite (+30), Legend (+50)
INSERT INTO contract_types (name, tier, matches_awarded, is_available) VALUES
    ('Bronze Contract', 'bronze', 3, true),
    ('Silver Contract', 'silver', 7, true),
    ('Gold Contract', 'gold', 15, true),
    ('Elite Contract', 'elite', 30, true),
    ('Legend Contract', 'legend', 50, true)
ON CONFLICT (name) DO NOTHING;

-- Contract packs: Bronze, Silver, Gold, Elite, Legend
-- Seed default contract packs for all existing users
INSERT INTO user_contract_packs (user_id, pack_name, contract_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source, opened, created_at)
SELECT
    u.id,
    'Bronze Contract Pack',
    4,
    70.00, 20.00, 8.00, 2.00, 0.00,
    'reward',
    false,
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_contract_packs ucp WHERE ucp.user_id = u.id AND ucp.pack_name = 'Bronze Contract Pack'
);

INSERT INTO user_contract_packs (user_id, pack_name, contract_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source, opened, created_at)
SELECT
    u.id,
    'Silver Contract Pack',
    4,
    30.00, 40.00, 20.00, 8.00, 2.00,
    'reward',
    false,
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_contract_packs ucp WHERE ucp.user_id = u.id AND ucp.pack_name = 'Silver Contract Pack'
);

INSERT INTO user_contract_packs (user_id, pack_name, contract_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source, opened, created_at)
SELECT
    u.id,
    'Gold Contract Pack',
    4,
    10.00, 25.00, 40.00, 20.00, 5.00,
    'reward',
    false,
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_contract_packs ucp WHERE ucp.user_id = u.id AND ucp.pack_name = 'Gold Contract Pack'
);

INSERT INTO user_contract_packs (user_id, pack_name, contract_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source, opened, created_at)
SELECT
    u.id,
    'Elite Contract Pack',
    4,
    0.00, 10.00, 30.00, 45.00, 15.00,
    'reward',
    false,
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_contract_packs ucp WHERE ucp.user_id = u.id AND ucp.pack_name = 'Elite Contract Pack'
);

INSERT INTO user_contract_packs (user_id, pack_name, contract_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source, opened, created_at)
SELECT
    u.id,
    'Legend Contract Pack',
    4,
    0.00, 0.00, 15.00, 40.00, 45.00,
    'reward',
    false,
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_contract_packs ucp WHERE ucp.user_id = u.id AND ucp.pack_name = 'Legend Contract Pack'
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_user_contracts_user ON user_contracts(user_id);
CREATE INDEX idx_user_contracts_user_type ON user_contracts(user_id, contract_type_id);
CREATE INDEX idx_user_contract_packs_user_opened ON user_contract_packs(user_id, opened);
CREATE INDEX idx_contract_types_available ON contract_types(is_available);
CREATE INDEX idx_user_cards_contracts_remaining ON user_cards(user_id, contracts_remaining);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE contract_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_contract_packs ENABLE ROW LEVEL SECURITY;

-- contract_types: public read (like pack_types, player_cards)
CREATE POLICY "Anyone can view contract types" ON contract_types FOR SELECT USING (true);

-- user_contracts: users can only read/write their own
CREATE POLICY "Users can view own contracts" ON user_contracts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own contracts" ON user_contracts FOR ALL USING (auth.uid() = user_id);

-- user_contract_packs: users can only read/write their own
CREATE POLICY "Users can view own contract packs" ON user_contract_packs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own contract packs" ON user_contract_packs FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================

-- Upsert user contract: increment quantity or insert new row
CREATE OR REPLACE FUNCTION upsert_user_contract(
    p_user_id UUID,
    p_contract_type_id UUID,
    p_quantity INT DEFAULT 1,
    p_source TEXT DEFAULT 'pack'
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    -- Try to update existing
    UPDATE user_contracts
    SET quantity = quantity + p_quantity
    WHERE user_id = p_user_id
      AND contract_type_id = p_contract_type_id
      AND source = p_source
    RETURNING id INTO v_id;
    
    IF v_id IS NOT NULL THEN
        RETURN v_id;
    END IF;
    
    -- Insert new if not exists
    INSERT INTO user_contracts (user_id, contract_type_id, quantity, source)
    VALUES (p_user_id, p_contract_type_id, p_quantity, p_source)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Consume 1 contract from each player in the playing XI on match completion
-- Only for the user's XI (home_user_id or away_user_id = p_user_id)
CREATE OR REPLACE FUNCTION consume_contracts_for_match(
    p_user_id UUID,
    p_match_id UUID,
    p_is_home_user BOOLEAN
) RETURNS TABLE(user_card_id UUID, contracts_remaining INT) AS $$
BEGIN
    RETURN QUERY
        UPDATE user_cards uc
        SET contracts_remaining = uc.contracts_remaining - 1
        FROM line_up lu
        WHERE lu.user_card_id = uc.id
          AND lu.match_id = p_match_id
          AND lu.is_home = p_is_home_user
          AND uc.user_id = p_user_id
          AND uc.contracts_remaining > 0
        RETURNING uc.id, uc.contracts_remaining;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply contract to user card: atomic operation
CREATE OR REPLACE FUNCTION apply_contract_to_card(
    p_user_id UUID,
    p_user_card_id UUID,
    p_contract_type_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_contract_type RECORD;
    v_user_card RECORD;
    v_new_remaining INT;
    v_new_max INT;
BEGIN
    -- Get contract type info
    SELECT matches_awarded INTO v_contract_type
    FROM contract_types
    WHERE id = p_contract_type_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contract type not found';
    END IF;
    
    -- Get user card info
    SELECT contracts_remaining, contracts_max INTO v_user_card
    FROM user_cards
    WHERE id = p_user_card_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User card not found or not owned by user';
    END IF;
    
    -- Check if there's a contract available
    PERFORM 1 FROM user_contracts
    WHERE user_id = p_user_id
      AND contract_type_id = p_contract_type_id
      AND quantity > 0
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No contracts of this type available';
    END IF;
    
    -- Calculate new values
    v_new_remaining := v_user_card.contracts_remaining + v_contract_type.matches_awarded;
    v_new_max := GREATEST(v_user_card.contracts_max, v_new_remaining);
    
    -- Decrement contract quantity (or delete if quantity becomes 0)
    UPDATE user_contracts
    SET quantity = quantity - 1
    WHERE user_id = p_user_id
      AND contract_type_id = p_contract_type_id
      AND quantity > 0;
    
    -- Delete row if quantity reached 0
    DELETE FROM user_contracts
    WHERE user_id = p_user_id
      AND contract_type_id = p_contract_type_id
      AND quantity = 0;
    
    -- Update user card
    UPDATE user_cards
    SET contracts_remaining = v_new_remaining,
        contracts_max = v_new_max
    WHERE id = p_user_card_id AND user_id = p_user_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Consume 1 contract from each player in the playing XI on match completion
-- Only for the user's XI (home_user_id or away_user_id = p_user_id)
CREATE OR REPLACE FUNCTION consume_contracts_for_match(
    p_user_id UUID,
    p_match_id UUID,
    p_is_home_user BOOLEAN
) RETURNS TABLE(user_card_id UUID, contracts_remaining INT) AS $$
BEGIN
    RETURN QUERY
        UPDATE user_cards uc
        SET contracts_remaining = uc.contracts_remaining - 1
        FROM line_up lu
        WHERE lu.user_card_id = uc.id
          AND lu.match_id = p_match_id
          AND lu.is_home = p_is_home_user
          AND uc.user_id = p_user_id
          AND uc.contracts_remaining > 0
        RETURNING uc.id, uc.contracts_remaining;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant level up contract packs (like grant_level_up_pack for cards)
CREATE OR REPLACE FUNCTION grant_level_up_contract_pack(
    p_user_id UUID,
    p_old_level INT,
    p_new_level INT
)
RETURNS VOID AS $$
DECLARE
    v_pack_name TEXT;
    v_probs JSONB;
BEGIN
    IF p_new_level <= p_old_level THEN
        RETURN;
    END IF;
    
    -- Determine pack based on new level
    IF p_new_level BETWEEN 2 AND 5 THEN
        v_pack_name := 'Bronze Contract Pack';
        v_probs := '{"bronze": 70, "silver": 20, "gold": 8, "elite": 2, "legend": 0}'::jsonb;
    ELSIF p_new_level BETWEEN 6 AND 10 THEN
        v_pack_name := 'Silver Contract Pack';
        v_probs := '{"bronze": 30, "silver": 40, "gold": 20, "elite": 8, "legend": 2}'::jsonb;
    ELSIF p_new_level BETWEEN 11 AND 15 THEN
        v_pack_name := 'Gold Contract Pack';
        v_probs := '{"bronze": 10, "silver": 25, "gold": 40, "elite": 20, "legend": 5}'::jsonb;
    ELSIF p_new_level BETWEEN 16 AND 20 THEN
        v_pack_name := 'Elite Contract Pack';
        v_probs := '{"bronze": 0, "silver": 10, "gold": 30, "elite": 45, "legend": 15}'::jsonb;
    ELSIF p_new_level >= 21 THEN
        v_pack_name := 'Legend Contract Pack';
        v_probs := '{"bronze": 0, "silver": 0, "gold": 15, "elite": 40, "legend": 45}'::jsonb;
    ELSE
        RETURN;
    END IF;
    
    INSERT INTO user_contract_packs (
        user_id,
        pack_name,
        contract_count,
        bronze_chance,
        silver_chance,
        gold_chance,
        elite_chance,
        legend_chance,
        source,
        opened,
        created_at
    ) VALUES (
        p_user_id,
        v_pack_name,
        4,
        (v_probs->>'bronze')::numeric,
        (v_probs->>'silver')::numeric,
        (v_probs->>'gold')::numeric,
        (v_probs->>'elite')::numeric,
        (v_probs->>'legend')::numeric,
        'level_up',
        false,
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
