-- Add scheduling columns to matches table for tournament match scheduling
ALTER TABLE matches ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS match_number INTEGER;

-- Index for efficient queries on scheduled tournament matches
CREATE INDEX IF NOT EXISTS idx_matches_tournament_scheduled 
  ON matches(tournament_id, scheduled_at) 
  WHERE tournament_id IS NOT NULL;
