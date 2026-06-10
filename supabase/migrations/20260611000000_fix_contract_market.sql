-- ============================================================
-- FIX: Apply missing contract market migration to production
-- This migration is idempotent and safe to run multiple times
-- ============================================================

-- 1) Create listing_type enum if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_type') THEN
        CREATE TYPE listing_type AS ENUM ('card', 'contract');
    END IF;
END$$;

-- 2) Add missing columns to transfer_market
ALTER TABLE transfer_market ADD COLUMN IF NOT EXISTS listing_type listing_type NOT NULL DEFAULT 'card';
ALTER TABLE transfer_market ADD COLUMN IF NOT EXISTS contract_type_id UUID REFERENCES contract_types(id);
ALTER TABLE transfer_market ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0 AND quantity <= 10);
ALTER TABLE transfer_market ALTER COLUMN user_card_id DROP NOT NULL;

-- 3) Create contract_types table if it doesn't exist
CREATE TABLE IF NOT EXISTS contract_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    tier TEXT NOT NULL CHECK (tier IN ('bronze', 'silver', 'gold', 'elite', 'legend')),
    matches_awarded INT NOT NULL CHECK (matches_awarded > 0),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4) Create user_contracts table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contract_type_id UUID NOT NULL REFERENCES contract_types(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    source TEXT NOT NULL CHECK (source IN ('reward', 'purchase', 'tournament', 'market', 'pack')),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, contract_type_id, source)
);

-- 5) Create user_contract_packs table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_contract_packs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- 6) Add contracts columns to user_cards if missing
ALTER TABLE user_cards ADD COLUMN IF NOT EXISTS contracts_remaining INT NOT NULL DEFAULT 7;
ALTER TABLE user_cards ADD COLUMN IF NOT EXISTS contracts_max INT NOT NULL DEFAULT 7;

-- 7) Seed contract types if empty
INSERT INTO contract_types (name, tier, matches_awarded, is_available) VALUES
    ('Bronze Contract', 'bronze', 3, true),
    ('Silver Contract', 'silver', 7, true),
    ('Gold Contract', 'gold', 15, true),
    ('Elite Contract', 'elite', 30, true),
    ('Legend Contract', 'legend', 50, true)
ON CONFLICT (name) DO NOTHING;

-- 8) Create index for contract listings
CREATE INDEX IF NOT EXISTS idx_transfer_market_contract ON transfer_market(contract_type_id) WHERE listing_type = 'contract';

-- 9) Enable RLS on new tables
ALTER TABLE contract_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_contract_packs ENABLE ROW LEVEL SECURITY;

-- RLS policies for contract_types
DROP POLICY IF EXISTS "Anyone can view contract types" ON contract_types;
CREATE POLICY "Anyone can view contract types" ON contract_types FOR SELECT USING (true);

-- RLS policies for user_contracts
DROP POLICY IF EXISTS "Users can view own contracts" ON user_contracts;
CREATE POLICY "Users can view own contracts" ON user_contracts FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own contracts" ON user_contracts;
CREATE POLICY "Users can insert own contracts" ON user_contracts FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own contracts" ON user_contracts;
CREATE POLICY "Users can update own contracts" ON user_contracts FOR UPDATE USING (auth.uid() = user_id);

-- RLS policies for user_contract_packs
DROP POLICY IF EXISTS "Users can view own contract packs" ON user_contract_packs;
CREATE POLICY "Users can view own contract packs" ON user_contract_packs FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own contract packs" ON user_contract_packs;
CREATE POLICY "Users can insert own contract packs" ON user_contract_packs FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own contract packs" ON user_contract_packs;
CREATE POLICY "Users can update own contract packs" ON user_contract_packs FOR UPDATE USING (auth.uid() = user_id);

-- 10) Create upsert_user_contract RPC function if it doesn't exist
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
