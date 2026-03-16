-- Add commentary_log JSONB array column to store all ball-by-ball events
ALTER TABLE multiplayer_matches
  ADD COLUMN IF NOT EXISTS commentary_log JSONB DEFAULT '[]'::jsonb;
