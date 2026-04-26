-- Create multiplayer_chats table for lobby chat
CREATE TABLE IF NOT EXISTS public.multiplayer_chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.multiplayer_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE multiplayer_chats;

-- Enable RLS
ALTER TABLE public.multiplayer_chats ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can view room chats" ON public.multiplayer_chats FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert chats" ON public.multiplayer_chats FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Indexing
CREATE INDEX idx_multiplayer_chats_room ON public.multiplayer_chats(room_id);
CREATE INDEX idx_multiplayer_chats_created ON public.multiplayer_chats(created_at);
