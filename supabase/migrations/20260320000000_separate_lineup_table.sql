-- ============================================================
-- Migration: Separate lineup from squad_players
-- Creates a dedicated lineup_players table for the Playing XI
-- and removes lineup-related columns from squad_players.
-- ============================================================

-- 1. Create the new lineup_players table
CREATE TABLE IF NOT EXISTS lineup_players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
    user_card_id UUID NOT NULL REFERENCES user_cards(id) ON DELETE CASCADE,
    batting_order INTEGER NOT NULL CHECK (batting_order >= 1 AND batting_order <= 11),
    is_captain BOOLEAN NOT NULL DEFAULT false,
    is_vice_captain BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(squad_id, batting_order),
    UNIQUE(squad_id, user_card_id)
);

CREATE INDEX idx_lineup_players_squad ON lineup_players(squad_id);

-- 2. Migrate existing Playing XI data into the new table
INSERT INTO lineup_players (squad_id, user_card_id, batting_order, is_captain, is_vice_captain)
SELECT
    sp.squad_id,
    sp.user_card_id,
    COALESCE(sp.batting_order, sp.position),
    sp.is_captain,
    sp.is_vice_captain
FROM squad_players sp
WHERE sp.is_playing_xi = true
  AND sp.batting_order IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3. Drop lineup columns from squad_players
ALTER TABLE squad_players
    DROP COLUMN IF EXISTS is_playing_xi,
    DROP COLUMN IF EXISTS is_captain,
    DROP COLUMN IF EXISTS is_vice_captain,
    DROP COLUMN IF EXISTS batting_order,
    DROP COLUMN IF EXISTS bowling_order;

-- 4. RLS policies for lineup_players
ALTER TABLE lineup_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own lineup players" ON lineup_players FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ));

CREATE POLICY "Users can manage own lineup players" ON lineup_players FOR ALL
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = lineup_players.squad_id AND teams.user_id = auth.uid()
    ));

-- 5. Enable realtime for the new table
ALTER PUBLICATION supabase_realtime ADD TABLE lineup_players;
