-- Add live match tracking columns to multiplayer_matches
ALTER TABLE multiplayer_matches
  ADD COLUMN IF NOT EXISTS current_innings INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS current_commentary TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS home_overs_display TEXT DEFAULT '0.0',
  ADD COLUMN IF NOT EXISTS away_overs_display TEXT DEFAULT '0.0',
  ADD COLUMN IF NOT EXISTS match_result TEXT,
  ADD COLUMN IF NOT EXISTS home_batsman TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS away_batsman TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS current_bowler TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_event_type TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_runs INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS target INT DEFAULT 0;
