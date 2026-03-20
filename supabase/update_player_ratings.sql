-- Update Player Ratings Script
-- Run this in Supabase SQL Editor

-- Update specific players by name
UPDATE player_cards SET 
  batting = 96, 
  bowling = 40, 
  fielding = 90, 
  rating = 96,
  rarity = 'legend'
WHERE player_name = 'Virat Kohli';

UPDATE player_cards SET 
  batting = 98, 
  bowling = 45, 
  fielding = 85, 
  rating = 98,
  rarity = 'legend'
WHERE player_name = 'Sachin Tendulkar';

-- Bulk update by pattern (example: boost all Indian players)
-- UPDATE player_cards SET 
--   batting = batting + 2,
--   bowling = bowling + 2,
--   fielding = fielding + 2,
--   rating = LEAST(rating + 2, 99)
-- WHERE nationality = 'India' AND rating < 90;

-- Update rarity based on rating
UPDATE player_cards SET rarity = 
  CASE 
    WHEN rating >= 95 THEN 'legend'
    WHEN rating >= 88 THEN 'elite'
    WHEN rating >= 80 THEN 'gold'
    WHEN rating >= 70 THEN 'silver'
    ELSE 'bronze'
  END
WHERE is_available = true;

-- Recalculate rating based on stats (weighted average)
UPDATE player_cards SET rating = 
  CASE role
    WHEN 'batsman' THEN 
      ROUND((batting * 0.6 + fielding * 0.3 + bowling * 0.1)::numeric, 0)
    WHEN 'bowler' THEN 
      ROUND((bowling * 0.6 + fielding * 0.3 + batting * 0.1)::numeric, 0)
    WHEN 'all_rounder' THEN 
      ROUND((batting * 0.35 + bowling * 0.35 + fielding * 0.3)::numeric, 0)
    WHEN 'wicket_keeper' THEN 
      ROUND((batting * 0.4 + fielding * 0.5 + bowling * 0.1)::numeric, 0)
    ELSE rating
  END
WHERE is_available = true;

-- Boost specific player types
-- Boost all wicket keepers' fielding
UPDATE player_cards SET 
  fielding = LEAST(fielding + 5, 99)
WHERE role = 'wicket_keeper' AND is_available = true;

-- Boost all fast bowlers (high bowling rating)
UPDATE player_cards SET 
  bowling = LEAST(bowling + 3, 99)
WHERE role = 'bowler' AND bowling >= 85 AND is_available = true;

-- Show updated player stats
SELECT 
  player_name,
  role,
  nationality,
  batting,
  bowling,
  fielding,
  rating,
  rarity
FROM player_cards
WHERE is_available = true
ORDER BY rating DESC, player_name
LIMIT 50;

-- Show distribution by rarity
SELECT 
  rarity,
  COUNT(*) as count,
  ROUND(AVG(rating), 1) as avg_rating,
  MIN(rating) as min_rating,
  MAX(rating) as max_rating
FROM player_cards
WHERE is_available = true
GROUP BY rarity
ORDER BY 
  CASE rarity 
    WHEN 'legend' THEN 1 
    WHEN 'elite' THEN 2 
    WHEN 'gold' THEN 3 
    WHEN 'silver' THEN 4 
    WHEN 'bronze' THEN 5 
  END;
