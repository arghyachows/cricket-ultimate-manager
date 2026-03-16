-- Add columns needed for server-side match simulation
ALTER TABLE multiplayer_matches
  ADD COLUMN IF NOT EXISTS home_bats_first BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS pitch_condition TEXT DEFAULT 'balanced',
  ADD COLUMN IF NOT EXISTS home_chemistry INT DEFAULT 50,
  ADD COLUMN IF NOT EXISTS away_chemistry INT DEFAULT 50;
