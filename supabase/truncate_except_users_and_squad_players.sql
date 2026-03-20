-- Clear ALL user game data.
--
-- KEEPS (static/structural tables — untouched):
--   users, player_cards, pack_types, season_rewards
--
-- CLEARS everything else:
--   user_cards, teams, squads, squad_players, lineup_players,
--   matches, match_events, multiplayer_rooms, room_presence,
--   match_challenges, multiplayer_matches, transfer_market,
--   market_bids, transactions, pack_openings, tournaments,
--   tournament_participants, daily_objectives, leaderboard,
--   user_player_stats
--
-- Run in Supabase SQL Editor.

BEGIN;

-- Truncate all user game data in dependency order (children first).
-- RESTART IDENTITY resets auto-increment sequences.
-- CASCADE handles any remaining FK references.
TRUNCATE TABLE
  lineup_players,
  market_bids,
  transfer_market,
  transactions,
  match_events,
  multiplayer_matches,
  match_challenges,
  room_presence,
  squad_players,
  pack_openings,
  tournament_participants,
  tournaments,
  daily_objectives,
  leaderboard,
  user_player_stats,
  matches,
  squads,
  teams,
  user_cards,
  users
RESTART IDENTITY CASCADE;

-- Reset all user progression back to starting values
UPDATE users SET
  coins           = 5000,
  premium_tokens  = 50,
  xp              = 0,
  level           = 1,
  season_tier     = 'bronze',
  season_points   = 0,
  matches_played  = 0,
  matches_won     = 0;

COMMIT;
