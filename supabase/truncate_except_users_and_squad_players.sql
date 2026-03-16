-- Reset most game data while keeping:
-- 1) all users
-- 2) only user_cards currently used in squad_players (players in squads)
--
-- Run in Supabase SQL Editor.

BEGIN;

-- 1) Clear match/session/progression data
TRUNCATE TABLE
  match_events,
  matches,
  multiplayer_matches,
  match_challenges,
  room_presence,
  transactions,
  transfer_market,
  pack_openings,
  tournament_participants,
  tournaments,
  daily_objectives,
  leaderboard,
  user_player_stats
RESTART IDENTITY CASCADE;

-- 2) Keep only cards that are currently in any squad
DELETE FROM user_cards uc
WHERE NOT EXISTS (
  SELECT 1
  FROM squad_players sp
  WHERE sp.user_card_id = uc.id
);

-- 3) Remove empty squads (no players left)
DELETE FROM squads s
WHERE NOT EXISTS (
  SELECT 1
  FROM squad_players sp
  WHERE sp.squad_id = s.id
);

-- 4) Remove teams with no remaining squads
DELETE FROM teams t
WHERE NOT EXISTS (
  SELECT 1
  FROM squads s
  WHERE s.team_id = t.id
);

COMMIT;
