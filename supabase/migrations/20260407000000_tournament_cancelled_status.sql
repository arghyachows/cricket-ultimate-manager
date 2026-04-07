-- Add 'cancelled' to tournament status CHECK constraint
ALTER TABLE tournaments DROP CONSTRAINT IF EXISTS tournaments_status_check;
ALTER TABLE tournaments ADD CONSTRAINT tournaments_status_check
  CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled'));

-- Add 't10' to match_format enum so T10 tournaments can be created
ALTER TYPE match_format ADD VALUE IF NOT EXISTS 't10';

-- Add missing RLS policies for tournament operations
-- Allow service role and authenticated users to insert/update tournament_participants
CREATE POLICY IF NOT EXISTS "Service can manage tournament participants"
  ON tournament_participants FOR ALL
  USING (true) WITH CHECK (true);

-- Allow service role to manage tournaments
CREATE POLICY IF NOT EXISTS "Service can manage tournaments"
  ON tournaments FOR ALL
  USING (true) WITH CHECK (true);

-- Allow service role to insert matches for tournaments
CREATE POLICY IF NOT EXISTS "Service can manage matches"
  ON matches FOR INSERT
  WITH CHECK (true);
