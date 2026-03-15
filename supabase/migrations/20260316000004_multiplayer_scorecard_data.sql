-- Add scorecard_data JSONB column for syncing detailed stats to watcher
ALTER TABLE multiplayer_matches
  ADD COLUMN IF NOT EXISTS scorecard_data JSONB DEFAULT '{}'::jsonb;
