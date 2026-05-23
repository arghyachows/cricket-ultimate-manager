-- Add More Known Cricket Players with ALL 17 Attributes
-- Run this in Supabase SQL Editor

-- Legendary Players with all 17 attributes
INSERT INTO player_cards (player_name, role, country, batting, bowling, fielding, stamina, pace, spin, aggression, technique, power, consistency, temperament, shot_making, running, accuracy, variations, yorkers, bouncer, rarity, is_available) VALUES
-- Indian Legends
('Sachin Tendulkar', 'batsman', 'India', 98, 45, 85, 85, 60, 55, 75, 98, 90, 95, 98, 95, 70, 70, 65, 60, 55, 'legend', true),
('Virat Kohli', 'batsman', 'India', 96, 40, 90, 88, 55, 50, 85, 95, 88, 92, 94, 93, 78, 72, 60, 58, 52, 'legend', true),
('MS Dhoni', 'wicket_keeper', 'India', 88, 35, 92, 80, 45, 40, 70, 85, 82, 88, 90, 80, 95, 65, 50, 45, 40, 'legend', true),
('Rohit Sharma', 'batsman', 'India', 94, 38, 82, 82, 50, 48, 78, 92, 90, 88, 88, 91, 72, 68, 55, 52, 48, 'elite', true),
('Jasprit Bumrah', 'bowler', 'India', 25, 97, 80, 85, 95, 45, 88, 30, 35, 85, 92, 28, 65, 95, 92, 95, 98, 'legend', true),
('Ravindra Jadeja', 'all_rounder', 'India', 78, 85, 95, 82, 55, 90, 72, 75, 70, 80, 82, 75, 88, 82, 88, 58, 52, 'elite', true),
('Hardik Pandya', 'all_rounder', 'India', 82, 80, 88, 85, 78, 55, 80, 78, 82, 78, 80, 80, 85, 78, 75, 72, 80, 'elite', true),
('KL Rahul', 'wicket_keeper', 'India', 88, 30, 85, 80, 42, 38, 72, 85, 82, 84, 86, 84, 90, 60, 48, 42, 38, 'elite', true),
('Rishabh Pant', 'wicket_keeper', 'India', 86, 25, 82, 78, 38, 32, 75, 82, 85, 80, 84, 88, 92, 55, 42, 35, 30, 'elite', true),
('Ravichandran Ashwin', 'bowler', 'India', 55, 92, 75, 78, 48, 95, 65, 58, 52, 78, 85, 55, 68, 88, 90, 52, 45, 'elite', true),

-- Australian Legends
('Steve Smith', 'batsman', 'Australia', 95, 42, 88, 85, 52, 50, 80, 94, 85, 90, 88, 92, 75, 68, 55, 50, 48, 'legend', true),
('David Warner', 'batsman', 'Australia', 92, 35, 85, 82, 48, 42, 88, 88, 92, 85, 86, 90, 80, 70, 52, 48, 45, 'elite', true),
('Pat Cummins', 'bowler', 'Australia', 45, 95, 82, 88, 92, 48, 82, 48, 50, 88, 90, 45, 72, 90, 88, 90, 92, 'legend', true),
('Glenn Maxwell', 'all_rounder', 'Australia', 85, 75, 90, 80, 65, 72, 78, 82, 88, 80, 82, 88, 85, 72, 70, 68, 70, 'elite', true),
('Mitchell Starc', 'bowler', 'Australia', 35, 94, 78, 82, 98, 45, 85, 38, 40, 85, 88, 35, 68, 92, 85, 92, 98, 'elite', true),
('Josh Hazlewood', 'bowler', 'Australia', 28, 93, 80, 85, 88, 50, 75, 32, 35, 88, 90, 28, 70, 90, 88, 88, 85, 'elite', true),
('Travis Head', 'batsman', 'Australia', 86, 40, 83, 80, 50, 48, 78, 84, 82, 82, 84, 85, 75, 68, 55, 50, 48, 'gold', true),
('Adam Zampa', 'bowler', 'Australia', 30, 88, 75, 78, 52, 90, 70, 35, 38, 80, 84, 32, 65, 85, 88, 55, 48, 'gold', true),

-- English Stars
('Joe Root', 'batsman', 'England', 94, 48, 86, 82, 55, 52, 75, 92, 85, 90, 90, 90, 72, 70, 58, 55, 50, 'legend', true),
('Ben Stokes', 'all_rounder', 'England', 88, 86, 90, 88, 85, 55, 90, 85, 88, 85, 88, 88, 88, 82, 82, 80, 88, 'legend', true),
('Jos Buttler', 'wicket_keeper', 'England', 90, 30, 88, 82, 45, 38, 80, 88, 90, 85, 88, 92, 88, 65, 48, 42, 38, 'elite', true),
('Jofra Archer', 'bowler', 'England', 32, 92, 82, 80, 96, 45, 88, 35, 40, 85, 88, 32, 70, 90, 85, 92, 96, 'elite', true),
('Jonny Bairstow', 'wicket_keeper', 'England', 87, 28, 84, 80, 40, 35, 75, 84, 82, 82, 85, 84, 88, 62, 45, 38, 35, 'elite', true),
('Mark Wood', 'bowler', 'England', 25, 90, 78, 78, 92, 48, 82, 30, 35, 82, 86, 25, 68, 88, 85, 90, 92, 'elite', true),
('Sam Curran', 'all_rounder', 'England', 75, 82, 85, 82, 80, 58, 78, 72, 75, 78, 80, 78, 78, 82, 78, 78, 75, 82, 'gold', true),

-- Pakistani Stars
('Babar Azam', 'batsman', 'Pakistan', 95, 38, 87, 85, 52, 48, 80, 94, 88, 90, 92, 92, 75, 70, 55, 50, 48, 'legend', true),
('Shaheen Afridi', 'bowler', 'Pakistan', 30, 94, 80, 82, 95, 45, 85, 35, 38, 85, 88, 30, 70, 92, 88, 92, 95, 'elite', true),
('Mohammad Rizwan', 'wicket_keeper', 'Pakistan', 86, 32, 88, 82, 45, 40, 72, 84, 80, 84, 86, 82, 90, 65, 50, 45, 40, 'elite', true),
('Shadab Khan', 'all_rounder', 'Pakistan', 72, 85, 86, 78, 58, 88, 75, 70, 72, 78, 80, 75, 80, 78, 82, 85, 60, 55, 'gold', true),
('Haris Rauf', 'bowler', 'Pakistan', 28, 88, 76, 80, 90, 48, 82, 32, 35, 82, 85, 28, 68, 88, 85, 88, 90, 'gold', true),

-- South African Stars
('Quinton de Kock', 'wicket_keeper', 'South Africa', 89, 25, 86, 80, 42, 38, 78, 86, 88, 84, 86, 88, 90, 62, 48, 42, 38, 'elite', true),
('Kagiso Rabada', 'bowler', 'South Africa', 35, 94, 82, 85, 92, 48, 82, 38, 42, 86, 90, 35, 72, 90, 88, 90, 92, 'elite', true),
('Aiden Markram', 'batsman', 'South Africa', 86, 45, 84, 80, 52, 50, 75, 84, 82, 82, 84, 85, 75, 70, 68, 55, 50, 48, 'gold', true),
('Anrich Nortje', 'bowler', 'South Africa', 30, 90, 78, 82, 95, 48, 85, 35, 38, 84, 88, 30, 70, 88, 85, 92, 95, 'elite', true),

-- New Zealand Stars
('Kane Williamson', 'batsman', 'New Zealand', 94, 42, 88, 82, 52, 50, 72, 94, 85, 92, 92, 90, 72, 70, 55, 50, 48, 'legend', true),
('Trent Boult', 'bowler', 'New Zealand', 32, 92, 80, 82, 88, 52, 78, 38, 40, 85, 88, 32, 70, 90, 88, 88, 85, 'elite', true),
('Devon Conway', 'batsman', 'New Zealand', 85, 30, 82, 78, 45, 40, 70, 82, 80, 82, 84, 84, 75, 68, 58, 48, 42, 38, 'gold', true),
('Tim Southee', 'bowler', 'New Zealand', 38, 89, 78, 80, 85, 50, 75, 42, 45, 82, 86, 38, 70, 88, 85, 85, 82, 'elite', true),

-- West Indies Stars
('Nicholas Pooran', 'wicket_keeper', 'West Indies', 84, 28, 85, 78, 40, 35, 78, 82, 85, 80, 84, 86, 88, 60, 45, 38, 35, 'gold', true),
('Andre Russell', 'all_rounder', 'West Indies', 82, 80, 84, 85, 85, 55, 88, 80, 88, 85, 82, 84, 88, 85, 80, 78, 82, 88, 'elite', true),
('Shimron Hetmyer', 'batsman', 'West Indies', 82, 35, 80, 78, 48, 42, 80, 80, 85, 78, 82, 84, 78, 72, 65, 52, 48, 45, 'gold', true),

-- Sri Lankan Stars
('Wanindu Hasaranga', 'all_rounder', 'Sri Lanka', 70, 88, 82, 78, 62, 90, 78, 68, 72, 78, 80, 75, 78, 85, 88, 65, 58, 'gold', true),
('Pathum Nissanka', 'batsman', 'Sri Lanka', 82, 30, 78, 75, 45, 40, 72, 80, 80, 78, 82, 82, 72, 65, 55, 48, 42, 38, 'gold', true),

-- Bangladesh Stars
('Shakib Al Hasan', 'all_rounder', 'Bangladesh', 82, 88, 85, 82, 65, 88, 78, 80, 78, 82, 84, 82, 82, 80, 85, 68, 62, 'elite', true),
('Mustafizur Rahman', 'bowler', 'Bangladesh', 25, 86, 75, 78, 88, 48, 80, 30, 35, 80, 84, 25, 68, 88, 85, 88, 85, 'gold', true),

-- Afghanistan Stars
('Rashid Khan', 'bowler', 'Afghanistan', 55, 95, 82, 80, 55, 98, 75, 58, 55, 82, 88, 55, 72, 92, 95, 58, 52, 'elite', true),
('Mohammad Nabi', 'all_rounder', 'Afghanistan', 76, 84, 80, 78, 68, 82, 75, 74, 72, 78, 80, 78, 78, 78, 82, 82, 70, 65, 'gold', true)

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
