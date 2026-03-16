-- Add toss metadata columns for multiplayer flow
ALTER TABLE multiplayer_matches
  ADD COLUMN IF NOT EXISTS toss_winner UUID REFERENCES teams(id),
  ADD COLUMN IF NOT EXISTS toss_decision TEXT CHECK (toss_decision IN ('bat', 'bowl'));
