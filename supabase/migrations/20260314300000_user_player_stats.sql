-- Player career stats persisted per user_card
CREATE TABLE IF NOT EXISTS user_player_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_card_id UUID NOT NULL REFERENCES user_cards(id) ON DELETE CASCADE,
  player_name TEXT NOT NULL DEFAULT '',
  matches INTEGER NOT NULL DEFAULT 0,
  runs INTEGER NOT NULL DEFAULT 0,
  balls_faced INTEGER NOT NULL DEFAULT 0,
  fours INTEGER NOT NULL DEFAULT 0,
  sixes INTEGER NOT NULL DEFAULT 0,
  wickets INTEGER NOT NULL DEFAULT 0,
  balls_bowled INTEGER NOT NULL DEFAULT 0,
  runs_conceded INTEGER NOT NULL DEFAULT 0,
  catches INTEGER NOT NULL DEFAULT 0,
  high_score INTEGER NOT NULL DEFAULT 0,
  best_bowling_wickets INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, user_card_id)
);

-- Enable RLS
ALTER TABLE user_player_stats ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own stats
CREATE POLICY "Users can read own stats"
  ON user_player_stats FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stats"
  ON user_player_stats FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stats"
  ON user_player_stats FOR UPDATE
  USING (auth.uid() = user_id);

-- RPC to upsert stats after a match (atomic increment)
CREATE OR REPLACE FUNCTION upsert_player_stats(
  p_user_id UUID,
  p_user_card_id UUID,
  p_player_name TEXT,
  p_matches INTEGER DEFAULT 0,
  p_runs INTEGER DEFAULT 0,
  p_balls_faced INTEGER DEFAULT 0,
  p_fours INTEGER DEFAULT 0,
  p_sixes INTEGER DEFAULT 0,
  p_wickets INTEGER DEFAULT 0,
  p_balls_bowled INTEGER DEFAULT 0,
  p_runs_conceded INTEGER DEFAULT 0,
  p_catches INTEGER DEFAULT 0,
  p_high_score INTEGER DEFAULT 0,
  p_best_bowling_wickets INTEGER DEFAULT 0
) RETURNS void AS $$
BEGIN
  INSERT INTO user_player_stats (
    user_id, user_card_id, player_name,
    matches, runs, balls_faced, fours, sixes,
    wickets, balls_bowled, runs_conceded,
    catches, high_score, best_bowling_wickets, updated_at
  ) VALUES (
    p_user_id, p_user_card_id, p_player_name,
    p_matches, p_runs, p_balls_faced, p_fours, p_sixes,
    p_wickets, p_balls_bowled, p_runs_conceded,
    p_catches, p_high_score, p_best_bowling_wickets, now()
  )
  ON CONFLICT (user_id, user_card_id) DO UPDATE SET
    player_name = EXCLUDED.player_name,
    matches = user_player_stats.matches + EXCLUDED.matches,
    runs = user_player_stats.runs + EXCLUDED.runs,
    balls_faced = user_player_stats.balls_faced + EXCLUDED.balls_faced,
    fours = user_player_stats.fours + EXCLUDED.fours,
    sixes = user_player_stats.sixes + EXCLUDED.sixes,
    wickets = user_player_stats.wickets + EXCLUDED.wickets,
    balls_bowled = user_player_stats.balls_bowled + EXCLUDED.balls_bowled,
    runs_conceded = user_player_stats.runs_conceded + EXCLUDED.runs_conceded,
    catches = user_player_stats.catches + EXCLUDED.catches,
    high_score = GREATEST(user_player_stats.high_score, EXCLUDED.high_score),
    best_bowling_wickets = GREATEST(user_player_stats.best_bowling_wickets, EXCLUDED.best_bowling_wickets),
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
