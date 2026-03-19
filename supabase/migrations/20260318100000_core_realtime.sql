-- Enable realtime for core user/card/squad tables
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE user_cards;
ALTER PUBLICATION supabase_realtime ADD TABLE squad_players;
