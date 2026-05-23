-- Migration: Add extended player attributes
-- Run this in Supabase SQL Editor

-- Add extended batting attributes
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS aggression INTEGER NOT NULL DEFAULT 50 CHECK (aggression >= 1 AND aggression <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS technique INTEGER NOT NULL DEFAULT 50 CHECK (technique >= 1 AND technique <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS power INTEGER NOT NULL DEFAULT 50 CHECK (power >= 1 AND power <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS consistency INTEGER NOT NULL DEFAULT 50 CHECK (consistency >= 1 AND consistency <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS temperament INTEGER NOT NULL DEFAULT 50 CHECK (temperament >= 1 AND temperament <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS shot_making INTEGER NOT NULL DEFAULT 50 CHECK (shot_making >= 1 AND shot_making <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS running INTEGER NOT NULL DEFAULT 50 CHECK (running >= 1 AND running <= 99);

-- Add extended bowling attributes
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS accuracy INTEGER NOT NULL DEFAULT 50 CHECK (accuracy >= 1 AND accuracy <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS variations INTEGER NOT NULL DEFAULT 50 CHECK (variations >= 1 AND variations <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS yorkers INTEGER NOT NULL DEFAULT 50 CHECK (yorkers >= 1 AND yorkers <= 99);
ALTER TABLE player_cards ADD COLUMN IF NOT EXISTS bouncer INTEGER NOT NULL DEFAULT 50 CHECK (bouncer >= 1 AND bouncer <= 99);

-- Verify columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'player_cards' 
AND column_name IN ('aggression', 'technique', 'power', 'consistency', 'temperament', 'shot_making', 'running', 'accuracy', 'variations', 'yorkers', 'bouncer')
ORDER BY column_name;