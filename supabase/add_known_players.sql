-- Add More Known Cricket Players
-- Run this in Supabase SQL Editor

-- Legendary Players
INSERT INTO player_cards (player_name, role, nationality, batting, bowling, fielding, rating, rarity, is_available) VALUES
-- Indian Legends
('Sachin Tendulkar', 'batsman', 'India', 98, 45, 85, 98, 'legend', true),
('Virat Kohli', 'batsman', 'India', 96, 40, 90, 96, 'legend', true),
('MS Dhoni', 'wicket_keeper', 'India', 88, 35, 92, 94, 'legend', true),
('Rohit Sharma', 'batsman', 'India', 94, 38, 82, 93, 'elite', true),
('Jasprit Bumrah', 'bowler', 'India', 25, 97, 80, 96, 'legend', true),
('Ravindra Jadeja', 'all_rounder', 'India', 78, 85, 95, 90, 'elite', true),
('Hardik Pandya', 'all_rounder', 'India', 82, 80, 88, 88, 'elite', true),
('KL Rahul', 'wicket_keeper', 'India', 88, 30, 85, 87, 'elite', true),
('Rishabh Pant', 'wicket_keeper', 'India', 86, 25, 82, 86, 'elite', true),
('Ravichandran Ashwin', 'bowler', 'India', 55, 92, 75, 89, 'elite', true),

-- Australian Legends
('Steve Smith', 'batsman', 'Australia', 95, 42, 88, 95, 'legend', true),
('David Warner', 'batsman', 'Australia', 92, 35, 85, 91, 'elite', true),
('Pat Cummins', 'bowler', 'Australia', 45, 95, 82, 94, 'legend', true),
('Glenn Maxwell', 'all_rounder', 'Australia', 85, 75, 90, 87, 'elite', true),
('Mitchell Starc', 'bowler', 'Australia', 35, 94, 78, 92, 'elite', true),
('Josh Hazlewood', 'bowler', 'Australia', 28, 93, 80, 91, 'elite', true),
('Travis Head', 'batsman', 'Australia', 86, 40, 83, 85, 'gold', true),
('Adam Zampa', 'bowler', 'Australia', 30, 88, 75, 84, 'gold', true),

-- English Stars
('Joe Root', 'batsman', 'England', 94, 48, 86, 94, 'legend', true),
('Ben Stokes', 'all_rounder', 'England', 88, 86, 90, 93, 'legend', true),
('Jos Buttler', 'wicket_keeper', 'England', 90, 30, 88, 90, 'elite', true),
('Jofra Archer', 'bowler', 'England', 32, 92, 82, 90, 'elite', true),
('Jonny Bairstow', 'wicket_keeper', 'England', 87, 28, 84, 86, 'elite', true),
('Mark Wood', 'bowler', 'England', 25, 90, 78, 87, 'elite', true),
('Sam Curran', 'all_rounder', 'England', 75, 82, 85, 84, 'gold', true),

-- Pakistani Stars
('Babar Azam', 'batsman', 'Pakistan', 95, 38, 87, 95, 'legend', true),
('Shaheen Afridi', 'bowler', 'Pakistan', 30, 94, 80, 93, 'elite', true),
('Mohammad Rizwan', 'wicket_keeper', 'Pakistan', 86, 32, 88, 88, 'elite', true),
('Shadab Khan', 'all_rounder', 'Pakistan', 72, 85, 86, 84, 'gold', true),
('Haris Rauf', 'bowler', 'Pakistan', 28, 88, 76, 84, 'gold', true),

-- South African Stars
('Quinton de Kock', 'wicket_keeper', 'South Africa', 89, 25, 86, 88, 'elite', true),
('Kagiso Rabada', 'bowler', 'South Africa', 35, 94, 82, 93, 'elite', true),
('Aiden Markram', 'batsman', 'South Africa', 86, 45, 84, 85, 'gold', true),
('Anrich Nortje', 'bowler', 'South Africa', 30, 90, 78, 88, 'elite', true),

-- New Zealand Stars
('Kane Williamson', 'batsman', 'New Zealand', 94, 42, 88, 94, 'legend', true),
('Trent Boult', 'bowler', 'New Zealand', 32, 92, 80, 91, 'elite', true),
('Devon Conway', 'batsman', 'New Zealand', 85, 30, 82, 84, 'gold', true),
('Tim Southee', 'bowler', 'New Zealand', 38, 89, 78, 87, 'elite', true),

-- West Indies Stars
('Nicholas Pooran', 'wicket_keeper', 'West Indies', 84, 28, 85, 84, 'gold', true),
('Andre Russell', 'all_rounder', 'West Indies', 82, 80, 84, 86, 'elite', true),
('Shimron Hetmyer', 'batsman', 'West Indies', 82, 35, 80, 82, 'gold', true),

-- Sri Lankan Stars
('Wanindu Hasaranga', 'all_rounder', 'Sri Lanka', 70, 88, 82, 85, 'gold', true),
('Pathum Nissanka', 'batsman', 'Sri Lanka', 82, 30, 78, 81, 'gold', true),

-- Bangladesh Stars
('Shakib Al Hasan', 'all_rounder', 'Bangladesh', 82, 88, 85, 89, 'elite', true),
('Mustafizur Rahman', 'bowler', 'Bangladesh', 25, 86, 75, 83, 'gold', true),

-- Afghanistan Stars
('Rashid Khan', 'bowler', 'Afghanistan', 55, 95, 82, 92, 'elite', true),
('Mohammad Nabi', 'all_rounder', 'Afghanistan', 76, 84, 80, 84, 'gold', true)

ON CONFLICT (player_name) DO NOTHING;

-- Update existing players to ensure they're available
UPDATE player_cards SET is_available = true WHERE player_name IN (
  'Sachin Tendulkar', 'Virat Kohli', 'MS Dhoni', 'Rohit Sharma', 'Jasprit Bumrah',
  'Steve Smith', 'Pat Cummins', 'Joe Root', 'Ben Stokes', 'Babar Azam',
  'Kane Williamson', 'Rashid Khan', 'Shaheen Afridi', 'Kagiso Rabada'
);

-- Show count of players by rarity
SELECT rarity, COUNT(*) as count 
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
