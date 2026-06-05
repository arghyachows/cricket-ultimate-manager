-- Add user_id column to squad_players for realtime subscription filtering
-- Required for TASK-13: squad_players realtime subscription must be scoped to owning user
--
-- The squad_players table links to squads -> teams -> users.  Denormalizing user_id here
-- so Supabase Realtime can filter on it directly (realtime filters can only reference
-- columns on the subscribed table, not joined tables).
--
-- NOTE: FK constraint is added LAST (after backfill) so it doesn't fail on the
-- initial sentinel default. This migration is designed to run cleanly on first
-- execution in any environment.

-- Step 1: Add column with a sentinel default (nullable first, FK after backfill)
ALTER TABLE squad_players
  ADD COLUMN user_id UUID DEFAULT '00000000-0000-0000-0000-000000000000';

-- Step 2: Backfill user_id from the squads -> teams join
UPDATE squad_players sp
SET user_id = t.user_id
FROM squads s
JOIN teams t ON t.id = s.team_id
WHERE sp.squad_id = s.id;

-- Step 3: Make the column NOT NULL now that all rows have real values
ALTER TABLE squad_players
  ALTER COLUMN user_id SET NOT NULL;

-- Step 4: Add FK constraint (now safe because every row has a real user_id)
ALTER TABLE squad_players
  ADD CONSTRAINT fk_squad_players_user
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 5: Index for the realtime filter
CREATE INDEX IF NOT EXISTS idx_squad_players_user ON squad_players(user_id);

-- Step 6: Trigger to auto-set user_id on insert (so app code doesn't have to pass it)
CREATE OR REPLACE FUNCTION set_squad_players_user_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT t.user_id INTO NEW.user_id
  FROM squads s
  JOIN teams t ON t.id = s.team_id
  WHERE s.id = NEW.squad_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_squad_players_user_id ON squad_players;
CREATE TRIGGER trg_squad_players_user_id
  BEFORE INSERT OR UPDATE OF squad_id ON squad_players
  FOR EACH ROW
  EXECUTE FUNCTION set_squad_players_user_id();

-- Simplify RLS policies to use the direct user_id column now that it exists.
-- Previously these policies relied on a join through squads -> teams, which
-- was correct but wasteful.  Direct-column lookup is faster and clearer.
DROP POLICY IF EXISTS "Users can view own squad players" ON squad_players;
DROP POLICY IF EXISTS "Users can manage own squad players" ON squad_players;

CREATE POLICY "Users can view own squad players" ON squad_players
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can manage own squad players" ON squad_players
  FOR ALL USING (user_id = auth.uid());
