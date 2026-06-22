-- ============================================================
-- Fix match_contract_consumption FK constraint
-- The FK on match_id only references matches(id), but multiplayer
-- matches exist in multiplayer_matches table. This causes a FK
-- violation that rolls back the entire RPC transaction, undoing
-- all contract decrements for multiplayer matches.
-- ============================================================

-- Drop the FK constraint so match_id can reference either table
ALTER TABLE match_contract_consumption
    DROP CONSTRAINT IF EXISTS match_contract_consumption_match_id_fkey;

-- Recreate as a plain UUID column (no FK) — the RPC already verifies
-- the match exists in either matches or multiplayer_matches before inserting
ALTER TABLE match_contract_consumption
    ALTER COLUMN match_id DROP NOT NULL;

ALTER TABLE match_contract_consumption
    ALTER COLUMN match_id SET NOT NULL;
