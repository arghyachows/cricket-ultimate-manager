# Player Management Scripts

This directory contains SQL scripts to manage player cards in the Cricket Ultimate Manager database.

## Scripts Overview

### 1. `add_known_players.sql`
Adds 50+ real cricket players including:
- **Legends**: Sachin Tendulkar, Virat Kohli, MS Dhoni, Steve Smith, Joe Root, Kane Williamson, etc.
- **Elite Players**: Rohit Sharma, Pat Cummins, Ben Stokes, Babar Azam, Shaheen Afridi, etc.
- **Gold Players**: Travis Head, Shadab Khan, Devon Conway, etc.

**Usage:**
1. Open Supabase Dashboard → SQL Editor
2. Copy and paste the entire script
3. Click "Run"
4. Check the output to see player counts by rarity

### 2. `update_player_ratings.sql`
Updates ratings for existing players with various methods:
- Update specific players by name
- Bulk updates by criteria (nationality, role, etc.)
- Auto-calculate ratings based on stats
- Adjust rarity based on rating

**Usage:**
1. Open the script and review the sections
2. Uncomment the sections you want to run
3. Run in Supabase SQL Editor
4. Check the reports at the end to verify changes

### 3. `manage_players.sql`
Comprehensive player management with 7 sections:
- **Section 1**: Update individual players
- **Section 2**: Bulk updates by criteria
- **Section 3**: Auto-calculate ratings
- **Section 4**: Role-specific adjustments
- **Section 5**: Find and fix issues
- **Section 6**: Reports and statistics
- **Section 7**: Quick fixes

**Usage:**
Run sections individually as needed. Each section is clearly marked.

## Quick Start

### Add All Known Players
```sql
-- Run add_known_players.sql in Supabase SQL Editor
```

### Update Specific Player
```sql
UPDATE player_cards SET 
  batting = 96, 
  bowling = 40, 
  fielding = 90, 
  rating = 96,
  rarity = 'legend'
WHERE player_name = 'Virat Kohli';
```

### Auto-Fix All Ratings
```sql
-- Recalculate ratings based on stats
UPDATE player_cards SET rating = 
  CASE role
    WHEN 'batsman' THEN ROUND((batting * 0.65 + fielding * 0.25 + bowling * 0.10)::numeric, 0)
    WHEN 'bowler' THEN ROUND((bowling * 0.65 + fielding * 0.25 + batting * 0.10)::numeric, 0)
    WHEN 'all_rounder' THEN ROUND((batting * 0.40 + bowling * 0.40 + fielding * 0.20)::numeric, 0)
    WHEN 'wicket_keeper' THEN ROUND((batting * 0.45 + fielding * 0.45 + bowling * 0.10)::numeric, 0)
    ELSE rating
  END
WHERE is_available = true;

-- Auto-assign rarity
UPDATE player_cards SET rarity = 
  CASE 
    WHEN rating >= 94 THEN 'legend'
    WHEN rating >= 87 THEN 'elite'
    WHEN rating >= 78 THEN 'gold'
    WHEN rating >= 65 THEN 'silver'
    ELSE 'bronze'
  END
WHERE is_available = true;
```

## Rating Guidelines

### Rarity Thresholds
- **Legend**: 94+ rating (Top 1% players)
- **Elite**: 87-93 rating (Top 5% players)
- **Gold**: 78-86 rating (Top 15% players)
- **Silver**: 65-77 rating (Average players)
- **Bronze**: Below 65 (Common players)

### Stat Ranges
- **90-99**: World-class
- **80-89**: International quality
- **70-79**: Good domestic player
- **60-69**: Average domestic player
- **Below 60**: Developing player

### Role-Specific Weights
- **Batsman**: Batting 65%, Fielding 25%, Bowling 10%
- **Bowler**: Bowling 65%, Fielding 25%, Batting 10%
- **All-rounder**: Batting 40%, Bowling 40%, Fielding 20%
- **Wicket Keeper**: Batting 45%, Fielding 45%, Bowling 10%

## Common Tasks

### View Top Players
```sql
SELECT player_name, role, nationality, rating, rarity
FROM player_cards
WHERE is_available = true
ORDER BY rating DESC
LIMIT 20;
```

### View Players by Country
```sql
SELECT player_name, role, rating, rarity
FROM player_cards
WHERE nationality = 'India' AND is_available = true
ORDER BY rating DESC;
```

### Find Mismatched Ratings
```sql
SELECT player_name, rating, rarity
FROM player_cards
WHERE is_available = true
  AND ((rating >= 94 AND rarity != 'legend')
    OR (rating >= 87 AND rating < 94 AND rarity != 'elite')
    OR (rating >= 78 AND rating < 87 AND rarity != 'gold'))
ORDER BY rating DESC;
```

## Tips

1. **Always backup** before running bulk updates
2. **Test on a few players** before running large updates
3. **Check reports** after updates to verify changes
4. **Use transactions** for complex multi-step updates
5. **Keep ratings balanced** - not everyone should be 90+

## Player List Added

The `add_known_players.sql` script adds these notable players:

**Indian**: Sachin Tendulkar, Virat Kohli, MS Dhoni, Rohit Sharma, Jasprit Bumrah, Ravindra Jadeja, Hardik Pandya, KL Rahul, Rishabh Pant, Ravichandran Ashwin

**Australian**: Steve Smith, David Warner, Pat Cummins, Glenn Maxwell, Mitchell Starc, Josh Hazlewood, Travis Head, Adam Zampa

**English**: Joe Root, Ben Stokes, Jos Buttler, Jofra Archer, Jonny Bairstow, Mark Wood, Sam Curran

**Pakistani**: Babar Azam, Shaheen Afridi, Mohammad Rizwan, Shadab Khan, Haris Rauf

**Others**: Kane Williamson, Trent Boult, Quinton de Kock, Kagiso Rabada, Rashid Khan, Shakib Al Hasan, Andre Russell, and more!

Total: 50+ real cricket players across all formats and nationalities.
