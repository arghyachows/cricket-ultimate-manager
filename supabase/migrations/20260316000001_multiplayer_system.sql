-- Migration: Multiplayer system with rooms, presence, and challenges

-- Multiplayer rooms table
CREATE TABLE IF NOT EXISTS multiplayer_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_name TEXT NOT NULL,
  room_code TEXT UNIQUE NOT NULL,
  max_players INT DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Room presence - tracks users currently in rooms
CREATE TABLE IF NOT EXISTS room_presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES multiplayer_rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  team_name TEXT NOT NULL,
  user_level INT DEFAULT 1,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

-- Match challenges table
CREATE TABLE IF NOT EXISTS match_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES multiplayer_rooms(id) ON DELETE CASCADE,
  challenger_id UUID REFERENCES users(id) ON DELETE CASCADE,
  challenged_id UUID REFERENCES users(id) ON DELETE CASCADE,
  challenger_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  challenged_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')) DEFAULT 'pending',
  match_format TEXT DEFAULT 't20',
  match_overs INT DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '5 minutes',
  responded_at TIMESTAMPTZ
);

-- Multiplayer matches table (extends regular matches)
CREATE TABLE IF NOT EXISTS multiplayer_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID REFERENCES match_challenges(id) ON DELETE SET NULL,
  home_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  away_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  home_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  away_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  home_team_name TEXT NOT NULL,
  away_team_name TEXT NOT NULL,
  match_format TEXT DEFAULT 't20',
  match_overs INT DEFAULT 20,
  status TEXT CHECK (status IN ('waiting', 'in_progress', 'completed', 'abandoned')) DEFAULT 'waiting',
  winner_user_id UUID REFERENCES users(id),
  home_score INT DEFAULT 0,
  home_wickets INT DEFAULT 0,
  away_score INT DEFAULT 0,
  away_wickets INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX idx_room_presence_room ON room_presence(room_id);
CREATE INDEX idx_room_presence_user ON room_presence(user_id);
CREATE INDEX idx_challenges_challenged ON match_challenges(challenged_id, status);
CREATE INDEX idx_challenges_room ON match_challenges(room_id, status);
CREATE INDEX idx_multiplayer_matches_users ON multiplayer_matches(home_user_id, away_user_id);

-- Enable RLS
ALTER TABLE multiplayer_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE multiplayer_matches ENABLE ROW LEVEL SECURITY;

-- Enable real-time for tables
ALTER PUBLICATION supabase_realtime ADD TABLE room_presence;
ALTER PUBLICATION supabase_realtime ADD TABLE match_challenges;
ALTER PUBLICATION supabase_realtime ADD TABLE multiplayer_matches;

-- RLS Policies
CREATE POLICY "Anyone can view rooms" ON multiplayer_rooms FOR SELECT USING (true);
CREATE POLICY "Anyone can view room presence" ON room_presence FOR SELECT USING (true);
CREATE POLICY "Users can join rooms" ON room_presence FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their presence" ON room_presence FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can leave rooms" ON room_presence FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view challenges" ON match_challenges FOR SELECT USING (
  auth.uid() = challenger_id OR auth.uid() = challenged_id
);
CREATE POLICY "Users can create challenges" ON match_challenges FOR INSERT WITH CHECK (auth.uid() = challenger_id);
CREATE POLICY "Users can update their challenges" ON match_challenges FOR UPDATE USING (
  auth.uid() = challenger_id OR auth.uid() = challenged_id
);

CREATE POLICY "Users can view their matches" ON multiplayer_matches FOR SELECT USING (
  auth.uid() = home_user_id OR auth.uid() = away_user_id
);
CREATE POLICY "System can create matches" ON multiplayer_matches FOR INSERT WITH CHECK (true);
CREATE POLICY "System can update matches" ON multiplayer_matches FOR UPDATE USING (true);

-- Function to clean up stale presence (users who haven't updated in 30 seconds)
CREATE OR REPLACE FUNCTION cleanup_stale_presence()
RETURNS void AS $$
BEGIN
  DELETE FROM room_presence
  WHERE last_seen < NOW() - INTERVAL '30 seconds';
END;
$$ LANGUAGE plpgsql;

-- Function to expire old challenges
CREATE OR REPLACE FUNCTION expire_old_challenges()
RETURNS void AS $$
BEGIN
  UPDATE match_challenges
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Insert default rooms
INSERT INTO multiplayer_rooms (room_name, room_code) VALUES
  ('Beginner Lounge', 'BEGINNER'),
  ('Pro Arena', 'PRO'),
  ('Elite Stadium', 'ELITE'),
  ('Global Championship', 'GLOBAL')
ON CONFLICT (room_code) DO NOTHING;
