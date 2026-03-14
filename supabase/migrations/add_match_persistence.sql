-- Migration: Add match persistence
-- This allows matches to be saved and resumed after app restart or logout

-- Table to store active/in-progress matches
CREATE TABLE IF NOT EXISTS active_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  match_format TEXT NOT NULL,
  match_overs INT NOT NULL,
  match_difficulty TEXT NOT NULL,
  home_team_name TEXT NOT NULL,
  away_team_name TEXT NOT NULL,
  home_bats_first BOOLEAN NOT NULL DEFAULT true,
  pitch_condition TEXT NOT NULL,
  weather_condition TEXT NOT NULL,
  user_won_toss BOOLEAN NOT NULL DEFAULT true,
  toss_decision TEXT NOT NULL,
  
  -- Match state
  current_innings INT NOT NULL DEFAULT 1,
  target INT NOT NULL DEFAULT 0,
  is_complete BOOLEAN NOT NULL DEFAULT false,
  home_won BOOLEAN,
  coins_awarded INT NOT NULL DEFAULT 0,
  xp_awarded INT NOT NULL DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT active_matches_user_id_unique UNIQUE(user_id)
);

-- Table to store match events (ball-by-ball)
CREATE TABLE IF NOT EXISTS active_match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES active_matches(id) ON DELETE CASCADE,
  innings INT NOT NULL,
  over_number INT NOT NULL,
  ball_number INT NOT NULL,
  batsman_card_id TEXT NOT NULL,
  bowler_card_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  runs INT NOT NULL DEFAULT 0,
  is_boundary BOOLEAN NOT NULL DEFAULT false,
  is_wicket BOOLEAN NOT NULL DEFAULT false,
  wicket_type TEXT,
  fielder_card_id TEXT,
  commentary TEXT NOT NULL,
  score_after INT NOT NULL DEFAULT 0,
  wickets_after INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table to store playing XI for active matches
CREATE TABLE IF NOT EXISTS active_match_squads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES active_matches(id) ON DELETE CASCADE,
  team_type TEXT NOT NULL CHECK (team_type IN ('home', 'away')),
  user_card_id TEXT NOT NULL,
  position INT NOT NULL,
  chemistry INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_active_matches_user_id ON active_matches(user_id);
CREATE INDEX IF NOT EXISTS idx_active_match_events_match_id ON active_match_events(match_id);
CREATE INDEX IF NOT EXISTS idx_active_match_events_innings ON active_match_events(match_id, innings);
CREATE INDEX IF NOT EXISTS idx_active_match_squads_match_id ON active_match_squads(match_id);

-- RLS Policies
ALTER TABLE active_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_match_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_match_squads ENABLE ROW LEVEL SECURITY;

-- Users can only access their own active matches
CREATE POLICY "Users can view own active matches"
  ON active_matches FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own active matches"
  ON active_matches FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own active matches"
  ON active_matches FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own active matches"
  ON active_matches FOR DELETE
  USING (auth.uid() = user_id);

-- Match events policies
CREATE POLICY "Users can view own match events"
  ON active_match_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM active_matches
      WHERE active_matches.id = active_match_events.match_id
      AND active_matches.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own match events"
  ON active_match_events FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM active_matches
      WHERE active_matches.id = active_match_events.match_id
      AND active_matches.user_id = auth.uid()
    )
  );

-- Match squads policies
CREATE POLICY "Users can view own match squads"
  ON active_match_squads FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM active_matches
      WHERE active_matches.id = active_match_squads.match_id
      AND active_matches.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own match squads"
  ON active_match_squads FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM active_matches
      WHERE active_matches.id = active_match_squads.match_id
      AND active_matches.user_id = auth.uid()
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_active_match_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER update_active_matches_timestamp
  BEFORE UPDATE ON active_matches
  FOR EACH ROW
  EXECUTE FUNCTION update_active_match_timestamp();

-- Function to clean up old completed matches (optional, run periodically)
CREATE OR REPLACE FUNCTION cleanup_old_active_matches()
RETURNS void AS $$
BEGIN
  DELETE FROM active_matches
  WHERE is_complete = true
  AND updated_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;
