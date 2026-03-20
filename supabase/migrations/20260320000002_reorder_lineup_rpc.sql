-- ============================================================
-- Migration: Add reorder_lineup RPC
-- Atomically reorders lineup batting orders in one UPDATE,
-- bypassing the UNIQUE(squad_id, batting_order) mid-update issue.
-- ============================================================

-- Fix the RLS policy to include an explicit WITH CHECK
DROP POLICY IF EXISTS "Users can manage own lineup players" ON lineup_players;

CREATE POLICY "Users can insert own lineup players" ON lineup_players FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ));

CREATE POLICY "Users can update own lineup players" ON lineup_players FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ));

CREATE POLICY "Users can delete own lineup players" ON lineup_players FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ));

-- Atomic reorder RPC (SECURITY DEFINER bypasses RLS and unique constraint ordering)
CREATE OR REPLACE FUNCTION reorder_lineup(
    p_squad_id UUID,
    p_player_ids UUID[]   -- UUIDs of lineup_players.id in desired batting order (1..N)
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
    FROM squads s
    JOIN teams t ON t.id = s.team_id
    WHERE s.id = p_squad_id;

    IF v_owner_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: squad does not belong to calling user';
    END IF;

    -- Single atomic UPDATE: sets all batting_orders at once using a JOIN,
    -- so the UNIQUE constraint is evaluated after all rows are written,
    -- not after each individual row update.
    UPDATE lineup_players lp
    SET batting_order = ord.new_order
    FROM (
        SELECT
            unnest(p_player_ids) AS player_id,
            generate_series(1, array_length(p_player_ids, 1)) AS new_order
    ) ord
    WHERE lp.id = ord.player_id
      AND lp.squad_id = p_squad_id;
END;
$$;
