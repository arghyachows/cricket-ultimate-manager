-- Comprehensive Player Management Script
-- Run sections as needed in Supabase SQL Editor

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 1: UPDATE INDIVIDUAL PLAYERS
-- ═══════════════════════════════════════════════════════════════════

-- Template for updating a single player
-- UPDATE player_cards SET 
--   batting = XX, 
--   bowling = XX, 
--   fielding = XX, 
--   rating = XX,
--   rarity = 'legend/elite/gold/silver/bronze'
-- WHERE player_name = 'Player Name';

-- Examples:
UPDATE player_cards SET batting = 97, bowling = 42, fielding = 88, rating = 97, rarity = 'legend' WHERE player_name = 'Virat Kohli';
UPDATE player_cards SET batting = 25, bowling = 97, fielding = 80, rating = 96, rarity = 'legend' WHERE player_name = 'Jasprit Bumrah';
UPDATE player_cards SET batting = 95, bowling = 42, fielding = 88, rating = 95, rarity = 'legend' WHERE player_name = 'Steve Smith';
UPDATE player_cards SET batting = 94, bowling = 48, fielding = 86, rating = 94, rarity = 'legend' WHERE player_name = 'Joe Root';

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 2: BULK UPDATES BY CRITERIA
-- ═══════════════════════════════════════════════════════════════════

-- Boost all players from a specific country
UPDATE player_cards SET 
  batting = LEAST(batting + 3, 99),
  bowling = LEAST(bowling + 3, 99),
  fielding = LEAST(fielding + 3, 99),
  rating = LEAST(rating + 3, 99)
WHERE nationality = 'India' AND rating < 95;

-- Nerf overrated players
UPDATE player_cards SET 
  rating = rating - 5,
  batting = batting - 3,
  bowling = bowling - 3
WHERE rating > 90 AND rarity = 'bronze';

-- Boost underrated players
UPDATE player_cards SET 
  rating = rating + 5,
  batting = batting + 3,
  bowling = bowling + 3
WHERE rating < 60 AND rarity IN ('gold', 'elite');

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 3: AUTO-CALCULATE RATINGS
-- ═══════════════════════════════════════════════════════════════════

-- Recalculate rating based on role-specific weighted stats
UPDATE player_cards SET rating = 
  CASE role
    WHEN 'batsman' THEN 
      ROUND((batting * 0.65 + fielding * 0.25 + bowling * 0.10)::numeric, 0)
    WHEN 'bowler' THEN 
      ROUND((bowling * 0.65 + fielding * 0.25 + batting * 0.10)::numeric, 0)
    WHEN 'all_rounder' THEN 
      ROUND((batting * 0.40 + bowling * 0.40 + fielding * 0.20)::numeric, 0)
    WHEN 'wicket_keeper' THEN 
      ROUND((batting * 0.45 + fielding * 0.45 + bowling * 0.10)::numeric, 0)
    ELSE rating
  END
WHERE is_available = true;

-- Auto-assign rarity based on rating
UPDATE player_cards SET rarity = 
  CASE 
    WHEN rating >= 94 THEN 'legend'
    WHEN rating >= 87 THEN 'elite'
    WHEN rating >= 78 THEN 'gold'
    WHEN rating >= 65 THEN 'silver'
    ELSE 'bronze'
  END
WHERE is_available = true;

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 4: ROLE-SPECIFIC ADJUSTMENTS
-- ═══════════════════════════════════════════════════════════════════

-- Boost wicket keepers' fielding
UPDATE player_cards SET 
  fielding = LEAST(fielding + 8, 99)
WHERE role = 'wicket_keeper' AND fielding < 85;

-- Boost fast bowlers (high pace)
UPDATE player_cards SET 
  bowling = LEAST(bowling + 4, 99)
WHERE role = 'bowler' AND bowling >= 80 AND nationality IN ('Australia', 'South Africa', 'Pakistan');

-- Boost spinners' accuracy
UPDATE player_cards SET 
  bowling = LEAST(bowling + 3, 99)
WHERE role = 'bowler' AND bowling >= 75 AND bowling < 85 AND nationality IN ('India', 'Sri Lanka', 'Afghanistan');

-- Boost all-rounders' balance
UPDATE player_cards SET 
  batting = LEAST(batting + 2, 99),
  bowling = LEAST(bowling + 2, 99),
  fielding = LEAST(fielding + 2, 99)
WHERE role = 'all_rounder' AND (batting + bowling) / 2 > 75;

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 5: FIND AND FIX ISSUES
-- ═══════════════════════════════════════════════════════════════════

-- Find players with mismatched rarity and rating
SELECT player_name, rating, rarity,
  CASE 
    WHEN rating >= 94 THEN 'legend'
    WHEN rating >= 87 THEN 'elite'
    WHEN rating >= 78 THEN 'gold'
    WHEN rating >= 65 THEN 'silver'
    ELSE 'bronze'
  END as suggested_rarity
FROM player_cards
WHERE is_available = true
  AND rarity != CASE 
    WHEN rating >= 94 THEN 'legend'
    WHEN rating >= 87 THEN 'elite'
    WHEN rating >= 78 THEN 'gold'
    WHEN rating >= 65 THEN 'silver'
    ELSE 'bronze'
  END
ORDER BY rating DESC;

-- Find batsmen with low batting stats
SELECT player_name, role, batting, rating, rarity
FROM player_cards
WHERE role = 'batsman' AND batting < 70 AND is_available = true
ORDER BY rating DESC;

-- Find bowlers with low bowling stats
SELECT player_name, role, bowling, rating, rarity
FROM player_cards
WHERE role = 'bowler' AND bowling < 70 AND is_available = true
ORDER BY rating DESC;

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 6: REPORTS AND STATISTICS
-- ═══════════════════════════════════════════════════════════════════

-- Top 20 players by rating
SELECT player_name, role, nationality, batting, bowling, fielding, rating, rarity
FROM player_cards
WHERE is_available = true
ORDER BY rating DESC, player_name
LIMIT 20;

-- Distribution by rarity
SELECT 
  rarity,
  COUNT(*) as count,
  ROUND(AVG(rating), 1) as avg_rating,
  MIN(rating) as min_rating,
  MAX(rating) as max_rating,
  ROUND(AVG(batting), 1) as avg_batting,
  ROUND(AVG(bowling), 1) as avg_bowling,
  ROUND(AVG(fielding), 1) as avg_fielding
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

-- Distribution by role
SELECT 
  role,
  COUNT(*) as count,
  ROUND(AVG(rating), 1) as avg_rating,
  ROUND(AVG(batting), 1) as avg_batting,
  ROUND(AVG(bowling), 1) as avg_bowling,
  ROUND(AVG(fielding), 1) as avg_fielding
FROM player_cards
WHERE is_available = true
GROUP BY role
ORDER BY count DESC;

-- Distribution by nationality
SELECT 
  nationality,
  COUNT(*) as count,
  ROUND(AVG(rating), 1) as avg_rating
FROM player_cards
WHERE is_available = true
GROUP BY nationality
ORDER BY count DESC, avg_rating DESC;

-- ═══════════════════════════════════════════════════════════════════
-- SECTION 7: QUICK FIXES
-- ═══════════════════════════════════════════════════════════════════

-- Ensure all stats are within valid range (0-99)
UPDATE player_cards SET 
  batting = LEAST(GREATEST(batting, 0), 99),
  bowling = LEAST(GREATEST(bowling, 0), 99),
  fielding = LEAST(GREATEST(fielding, 0), 99),
  rating = LEAST(GREATEST(rating, 0), 99)
WHERE is_available = true;

-- Remove duplicate players (keep highest rated)
DELETE FROM player_cards a
USING player_cards b
WHERE a.id < b.id 
  AND a.player_name = b.player_name
  AND a.rating < b.rating;

-- Mark low-quality players as unavailable
UPDATE player_cards SET is_available = false
WHERE rating < 40 AND rarity = 'bronze';
