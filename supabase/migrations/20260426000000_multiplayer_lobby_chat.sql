-- Create multiplayer_chats table
CREATE TABLE IF NOT EXISTS multiplayer_chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES multiplayer_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE multiplayer_chats;

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_multiplayer_chats_room_id ON multiplayer_chats(room_id);
CREATE INDEX IF NOT EXISTS idx_multiplayer_chats_created_at ON multiplayer_chats(created_at);

-- RLS Policies
ALTER TABLE multiplayer_chats ENABLE ROW LEVEL SECURITY;

-- Anyone in the room can read messages
CREATE POLICY "Anyone can read room messages" 
ON multiplayer_chats FOR SELECT 
USING (true);

-- Authenticated users can insert their own messages
CREATE POLICY "Users can insert their own messages" 
ON multiplayer_chats FOR INSERT 
WITH CHECK (auth.uid() = user_id);
