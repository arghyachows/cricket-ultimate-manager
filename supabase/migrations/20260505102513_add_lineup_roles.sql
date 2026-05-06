-- Add explicit roles for cricket lineup
ALTER TABLE lineup_players
  ADD COLUMN is_wicket_keeper BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN is_bowler_1 BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN is_bowler_2 BOOLEAN NOT NULL DEFAULT false;
