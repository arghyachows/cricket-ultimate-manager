-- ============================================================
-- Migration: Fix reorder_lineup RPC
-- Problem 1: UNIQUE(squad_id, batting_order) is IMMEDIATE — row-level
--   conflict on swap even in a single UPDATE.
-- Problem 2: CHECK (batting_order >= 1 AND batting_order <= 11) blocks
--   any temporary offset strategy.
-- Fix: Make the unique constraint DEFERRABLE, then defer it inside
--   the RPC so the constraint is only checked at COMMIT, not per-row.
-- ============================================================

-- Step 1: Replace the unique constraint with a DEFERRABLE version
ALTER TABLE lineup_players
    DROP CONSTRAINT IF EXISTS lineup_players_squad_id_batting_order_key;

ALTER TABLE lineup_players
    ADD CONSTRAINT lineup_players_squad_id_batting_order_key
    UNIQUE (squad_id, batting_order)
    DEFERRABLE INITIALLY IMMEDIATE;

-- Step 2: Recreate the function using SET CONSTRAINTS ... DEFERRED
CREATE OR REPLACE FUNCTION reorder_lineup(
    p_squad_id   UUID,
    p_player_ids UUID[]  -- lineup_players.id values in desired batting order (1..N)
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    -- Verify the squad belongs to the calling user
    SELECT t.user_id INTO v_owner_id
    FROM   squads s
    JOIN   teams  t ON t.id = s.team_id
    WHERE  s.id = p_squad_id;

    IF v_owner_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: squad does not belong to calling user';
    END IF;

    -- Defer the unique constraint so it is checked at end-of-transaction,
    -- not after each individual row update
    SET CONSTRAINTS lineup_players_squad_id_batting_order_key DEFERRED;

    -- Single UPDATE: safe now because constraint check is deferred
    UPDATE lineup_players lp
    SET    batting_order = ord.new_order
    FROM (
        SELECT unnest(p_player_ids)                              AS player_id,
               generate_series(1, array_length(p_player_ids, 1)) AS new_order
    ) ord
    WHERE  lp.id       = ord.player_id
      AND  lp.squad_id = p_squad_id;
END;
$$;
