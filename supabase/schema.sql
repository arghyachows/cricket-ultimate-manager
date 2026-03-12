-- ============================================================
-- CRICKET ULTIMATE MANAGER - Full Supabase Database Schema
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE player_role AS ENUM ('batsman', 'bowler', 'all_rounder', 'wicket_keeper');
CREATE TYPE card_rarity AS ENUM ('bronze', 'silver', 'gold', 'elite', 'legend');
CREATE TYPE card_type AS ENUM ('standard', 'team_of_the_week', 'event', 'icon', 'flashback');
CREATE TYPE match_status AS ENUM ('pending', 'in_progress', 'completed', 'abandoned');
CREATE TYPE match_format AS ENUM ('t20', 'odi', 'test');
CREATE TYPE listing_status AS ENUM ('active', 'sold', 'expired', 'cancelled');
CREATE TYPE transaction_type AS ENUM ('pack_purchase', 'market_buy', 'market_sell', 'match_reward', 'tournament_reward', 'daily_reward', 'card_upgrade');
CREATE TYPE pitch_type AS ENUM ('batting_friendly', 'bowling_friendly', 'balanced', 'spin_friendly', 'seam_friendly');
CREATE TYPE event_type AS ENUM ('dot_ball', 'single', 'double', 'triple', 'four', 'six', 'wicket', 'wide', 'no_ball', 'bye', 'leg_bye');
CREATE TYPE objective_status AS ENUM ('active', 'completed', 'claimed', 'expired');
CREATE TYPE season_tier AS ENUM ('bronze', 'silver', 'gold', 'elite', 'champion');

-- ============================================================
-- USERS TABLE
-- ============================================================

CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    coins INTEGER NOT NULL DEFAULT 5000,
    premium_tokens INTEGER NOT NULL DEFAULT 50,
    xp INTEGER NOT NULL DEFAULT 0,
    level INTEGER NOT NULL DEFAULT 1,
    season_tier season_tier NOT NULL DEFAULT 'bronze',
    season_points INTEGER NOT NULL DEFAULT 0,
    matches_played INTEGER NOT NULL DEFAULT 0,
    matches_won INTEGER NOT NULL DEFAULT 0,
    last_daily_reward TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PLAYER CARDS (Master card definitions)
-- ============================================================

CREATE TABLE player_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_name TEXT NOT NULL,
    country TEXT NOT NULL,
    league TEXT,
    team TEXT,
    role player_role NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 99),
    batting INTEGER NOT NULL CHECK (batting >= 1 AND batting <= 99),
    bowling INTEGER NOT NULL CHECK (bowling >= 1 AND bowling <= 99),
    fielding INTEGER NOT NULL CHECK (fielding >= 1 AND fielding <= 99),
    stamina INTEGER NOT NULL CHECK (stamina >= 1 AND stamina <= 99),
    pace INTEGER NOT NULL DEFAULT 50 CHECK (pace >= 1 AND pace <= 99),
    spin INTEGER NOT NULL DEFAULT 50 CHECK (spin >= 1 AND spin <= 99),
    rarity card_rarity NOT NULL,
    card_type card_type NOT NULL DEFAULT 'standard',
    image_url TEXT,
    country_flag_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    available_from TIMESTAMPTZ,
    available_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- USER CARDS (Cards owned by users)
-- ============================================================

CREATE TABLE user_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id UUID NOT NULL REFERENCES player_cards(id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 1,
    xp INTEGER NOT NULL DEFAULT 0,
    form INTEGER NOT NULL DEFAULT 50 CHECK (form >= 0 AND form <= 100),
    fatigue INTEGER NOT NULL DEFAULT 0 CHECK (fatigue >= 0 AND fatigue <= 100),
    matches_played INTEGER NOT NULL DEFAULT 0,
    runs_scored INTEGER NOT NULL DEFAULT 0,
    wickets_taken INTEGER NOT NULL DEFAULT 0,
    is_tradeable BOOLEAN NOT NULL DEFAULT true,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TEAMS
-- ============================================================

CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    logo_url TEXT,
    chemistry INTEGER NOT NULL DEFAULT 0,
    overall_rating INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, team_name)
);

-- ============================================================
-- SQUADS
-- ============================================================

CREATE TABLE squads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    squad_name TEXT NOT NULL DEFAULT 'Main Squad',
    formation TEXT NOT NULL DEFAULT '4-3-4',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SQUAD PLAYERS
-- ============================================================

CREATE TABLE squad_players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
    user_card_id UUID NOT NULL REFERENCES user_cards(id) ON DELETE CASCADE,
    position INTEGER NOT NULL CHECK (position >= 1 AND position <= 30),
    is_playing_xi BOOLEAN NOT NULL DEFAULT false,
    is_captain BOOLEAN NOT NULL DEFAULT false,
    is_vice_captain BOOLEAN NOT NULL DEFAULT false,
    batting_order INTEGER,
    bowling_order INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(squad_id, position),
    UNIQUE(squad_id, user_card_id)
);

-- ============================================================
-- MATCHES
-- ============================================================

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    home_team_id UUID NOT NULL REFERENCES teams(id),
    away_team_id UUID NOT NULL REFERENCES teams(id),
    home_user_id UUID NOT NULL REFERENCES users(id),
    away_user_id UUID REFERENCES users(id), -- NULL for AI matches
    format match_format NOT NULL DEFAULT 't20',
    status match_status NOT NULL DEFAULT 'pending',
    pitch_condition pitch_type NOT NULL DEFAULT 'balanced',
    toss_winner UUID REFERENCES teams(id),
    toss_decision TEXT CHECK (toss_decision IN ('bat', 'bowl')),
    home_score INTEGER NOT NULL DEFAULT 0,
    home_wickets INTEGER NOT NULL DEFAULT 0,
    home_overs NUMERIC(5,1) NOT NULL DEFAULT 0,
    away_score INTEGER NOT NULL DEFAULT 0,
    away_wickets INTEGER NOT NULL DEFAULT 0,
    away_overs NUMERIC(5,1) NOT NULL DEFAULT 0,
    winner_team_id UUID REFERENCES teams(id),
    winner_user_id UUID REFERENCES users(id),
    man_of_match UUID REFERENCES user_cards(id),
    home_chemistry INTEGER NOT NULL DEFAULT 0,
    away_chemistry INTEGER NOT NULL DEFAULT 0,
    coins_reward INTEGER NOT NULL DEFAULT 0,
    xp_reward INTEGER NOT NULL DEFAULT 0,
    tournament_id UUID,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MATCH EVENTS (Ball by ball)
-- ============================================================

CREATE TABLE match_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    innings INTEGER NOT NULL CHECK (innings IN (1, 2)),
    over_number INTEGER NOT NULL,
    ball_number INTEGER NOT NULL CHECK (ball_number >= 1 AND ball_number <= 6),
    batting_team_id UUID NOT NULL REFERENCES teams(id),
    bowling_team_id UUID NOT NULL REFERENCES teams(id),
    batsman_card_id UUID NOT NULL REFERENCES user_cards(id),
    bowler_card_id UUID NOT NULL REFERENCES user_cards(id),
    event_type event_type NOT NULL,
    runs INTEGER NOT NULL DEFAULT 0,
    is_boundary BOOLEAN NOT NULL DEFAULT false,
    is_wicket BOOLEAN NOT NULL DEFAULT false,
    wicket_type TEXT,
    fielder_card_id UUID REFERENCES user_cards(id),
    commentary TEXT,
    score_after INTEGER NOT NULL DEFAULT 0,
    wickets_after INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSFER MARKET
-- ============================================================

CREATE TABLE transfer_market (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID NOT NULL REFERENCES users(id),
    user_card_id UUID NOT NULL REFERENCES user_cards(id),
    buy_now_price INTEGER NOT NULL CHECK (buy_now_price > 0),
    starting_bid INTEGER NOT NULL CHECK (starting_bid > 0),
    current_bid INTEGER NOT NULL DEFAULT 0,
    current_bidder_id UUID REFERENCES users(id),
    status listing_status NOT NULL DEFAULT 'active',
    expires_at TIMESTAMPTZ NOT NULL,
    sold_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSACTIONS
-- ============================================================

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    type transaction_type NOT NULL,
    coins_amount INTEGER NOT NULL DEFAULT 0,
    premium_amount INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PACKS
-- ============================================================

CREATE TABLE pack_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    coin_cost INTEGER NOT NULL DEFAULT 0,
    premium_cost INTEGER NOT NULL DEFAULT 0,
    card_count INTEGER NOT NULL DEFAULT 3,
    bronze_chance NUMERIC(5,2) NOT NULL DEFAULT 60.00,
    silver_chance NUMERIC(5,2) NOT NULL DEFAULT 25.00,
    gold_chance NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    elite_chance NUMERIC(5,2) NOT NULL DEFAULT 4.00,
    legend_chance NUMERIC(5,2) NOT NULL DEFAULT 1.00,
    is_available BOOLEAN NOT NULL DEFAULT true,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE pack_openings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    pack_type_id UUID NOT NULL REFERENCES pack_types(id),
    cards_received UUID[] NOT NULL DEFAULT '{}',
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TOURNAMENTS
-- ============================================================

CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    format match_format NOT NULL DEFAULT 't20',
    max_participants INTEGER NOT NULL DEFAULT 16,
    current_participants INTEGER NOT NULL DEFAULT 0,
    entry_fee_coins INTEGER NOT NULL DEFAULT 0,
    entry_fee_premium INTEGER NOT NULL DEFAULT 0,
    prize_coins INTEGER NOT NULL DEFAULT 0,
    prize_packs UUID[],
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed')),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tournament_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    team_id UUID NOT NULL REFERENCES teams(id),
    position INTEGER,
    points INTEGER NOT NULL DEFAULT 0,
    matches_played INTEGER NOT NULL DEFAULT 0,
    matches_won INTEGER NOT NULL DEFAULT 0,
    net_run_rate NUMERIC(6,3) NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, user_id)
);

-- ============================================================
-- DAILY OBJECTIVES
-- ============================================================

CREATE TABLE daily_objectives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    target_value INTEGER NOT NULL DEFAULT 1,
    current_value INTEGER NOT NULL DEFAULT 0,
    reward_coins INTEGER NOT NULL DEFAULT 0,
    reward_premium INTEGER NOT NULL DEFAULT 0,
    reward_xp INTEGER NOT NULL DEFAULT 0,
    status objective_status NOT NULL DEFAULT 'active',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, title, date)
);

-- ============================================================
-- SEASON REWARDS
-- ============================================================

CREATE TABLE season_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tier season_tier NOT NULL,
    level INTEGER NOT NULL,
    reward_coins INTEGER NOT NULL DEFAULT 0,
    reward_premium INTEGER NOT NULL DEFAULT 0,
    reward_pack_id UUID REFERENCES pack_types(id),
    reward_card_id UUID REFERENCES player_cards(id),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tier, level)
);

-- ============================================================
-- LEADERBOARD CACHE
-- ============================================================

CREATE TABLE leaderboard (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    username TEXT NOT NULL,
    season_points INTEGER NOT NULL DEFAULT 0,
    matches_won INTEGER NOT NULL DEFAULT 0,
    overall_rating INTEGER NOT NULL DEFAULT 0,
    rank INTEGER,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_user_cards_user ON user_cards(user_id);
CREATE INDEX idx_user_cards_card ON user_cards(card_id);
CREATE INDEX idx_squad_players_squad ON squad_players(squad_id);
CREATE INDEX idx_matches_home ON matches(home_user_id);
CREATE INDEX idx_matches_away ON matches(away_user_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_match_events_match ON match_events(match_id);
CREATE INDEX idx_match_events_innings ON match_events(match_id, innings);
CREATE INDEX idx_transfer_market_status ON transfer_market(status);
CREATE INDEX idx_transfer_market_expires ON transfer_market(expires_at);
CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_daily_objectives_user_date ON daily_objectives(user_id, date);
CREATE INDEX idx_leaderboard_rank ON leaderboard(rank);
CREATE INDEX idx_player_cards_rarity ON player_cards(rarity);
CREATE INDEX idx_player_cards_role ON player_cards(role);
CREATE INDEX idx_player_cards_rating ON player_cards(rating);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE squad_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_market ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_openings ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_objectives ENABLE ROW LEVEL SECURITY;

-- Users can read all profiles but only update their own
CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, username, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', 'Player_' || LEFT(NEW.id::text, 8)), COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- User cards - users can only see their own
CREATE POLICY "Users can view own cards" ON user_cards FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own cards" ON user_cards FOR ALL USING (auth.uid() = user_id);

-- Teams
CREATE POLICY "Users can view all teams" ON teams FOR SELECT USING (true);
CREATE POLICY "Users can manage own teams" ON teams FOR ALL USING (auth.uid() = user_id);

-- Squads
CREATE POLICY "Users can view own squads" ON squads FOR SELECT
    USING (EXISTS (SELECT 1 FROM teams WHERE teams.id = squads.team_id AND teams.user_id = auth.uid()));
CREATE POLICY "Users can manage own squads" ON squads FOR ALL
    USING (EXISTS (SELECT 1 FROM teams WHERE teams.id = squads.team_id AND teams.user_id = auth.uid()));

-- Squad players
CREATE POLICY "Users can view own squad players" ON squad_players FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = squad_players.squad_id AND teams.user_id = auth.uid()
    ));
CREATE POLICY "Users can manage own squad players" ON squad_players FOR ALL
    USING (EXISTS (
        SELECT 1 FROM squads
        JOIN teams ON teams.id = squads.team_id
        WHERE squads.id = squad_players.squad_id AND teams.user_id = auth.uid()
    ));

-- Matches - all can view, participants can manage
CREATE POLICY "Anyone can view matches" ON matches FOR SELECT USING (true);
CREATE POLICY "Match participants can manage" ON matches FOR ALL
    USING (auth.uid() = home_user_id OR auth.uid() = away_user_id);

-- Match events
CREATE POLICY "Anyone can view match events" ON match_events FOR SELECT USING (true);

-- Transfer market - all can view active, owners can manage
CREATE POLICY "Anyone can view active listings" ON transfer_market FOR SELECT USING (true);
CREATE POLICY "Sellers can manage own listings" ON transfer_market FOR ALL USING (auth.uid() = seller_id);

-- Transactions
CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);

-- Pack openings
CREATE POLICY "Users can view own pack openings" ON pack_openings FOR SELECT USING (auth.uid() = user_id);

-- Daily objectives
CREATE POLICY "Users can view own objectives" ON daily_objectives FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own objectives" ON daily_objectives FOR UPDATE USING (auth.uid() = user_id);

-- Public read tables
ALTER TABLE player_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view player cards" ON player_cards FOR SELECT USING (true);

ALTER TABLE pack_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view pack types" ON pack_types FOR SELECT USING (true);

ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view tournaments" ON tournaments FOR SELECT USING (true);

ALTER TABLE tournament_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view tournament participants" ON tournament_participants FOR SELECT USING (true);

ALTER TABLE season_rewards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view season rewards" ON season_rewards FOR SELECT USING (true);

ALTER TABLE leaderboard ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view leaderboard" ON leaderboard FOR SELECT USING (true);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER teams_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER squads_updated_at BEFORE UPDATE ON squads FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Calculate team chemistry
CREATE OR REPLACE FUNCTION calculate_team_chemistry(p_squad_id UUID)
RETURNS INTEGER AS $$
DECLARE
    chemistry INTEGER := 0;
    player_count INTEGER;
    country_groups RECORD;
    team_groups RECORD;
    league_groups RECORD;
    role_balance RECORD;
BEGIN
    -- Country links: +3 per pair from same country in playing XI
    FOR country_groups IN
        SELECT pc.country, COUNT(*) as cnt
        FROM squad_players sp
        JOIN user_cards uc ON uc.id = sp.user_card_id
        JOIN player_cards pc ON pc.id = uc.card_id
        WHERE sp.squad_id = p_squad_id AND sp.is_playing_xi = true
        GROUP BY pc.country
        HAVING COUNT(*) > 1
    LOOP
        chemistry := chemistry + (country_groups.cnt * (country_groups.cnt - 1) / 2) * 3;
    END LOOP;

    -- Team links: +5 per pair from same team
    FOR team_groups IN
        SELECT pc.team, COUNT(*) as cnt
        FROM squad_players sp
        JOIN user_cards uc ON uc.id = sp.user_card_id
        JOIN player_cards pc ON pc.id = uc.card_id
        WHERE sp.squad_id = p_squad_id AND sp.is_playing_xi = true AND pc.team IS NOT NULL
        GROUP BY pc.team
        HAVING COUNT(*) > 1
    LOOP
        chemistry := chemistry + (team_groups.cnt * (team_groups.cnt - 1) / 2) * 5;
    END LOOP;

    -- League links: +2 per pair from same league
    FOR league_groups IN
        SELECT pc.league, COUNT(*) as cnt
        FROM squad_players sp
        JOIN user_cards uc ON uc.id = sp.user_card_id
        JOIN player_cards pc ON pc.id = uc.card_id
        WHERE sp.squad_id = p_squad_id AND sp.is_playing_xi = true AND pc.league IS NOT NULL
        GROUP BY pc.league
        HAVING COUNT(*) > 1
    LOOP
        chemistry := chemistry + (league_groups.cnt * (league_groups.cnt - 1) / 2) * 2;
    END LOOP;

    -- Role balance bonus: +10 if has all 4 roles in XI
    SELECT COUNT(DISTINCT pc.role) INTO player_count
    FROM squad_players sp
    JOIN user_cards uc ON uc.id = sp.user_card_id
    JOIN player_cards pc ON pc.id = uc.card_id
    WHERE sp.squad_id = p_squad_id AND sp.is_playing_xi = true;

    IF player_count = 4 THEN
        chemistry := chemistry + 10;
    END IF;

    -- Cap at 100
    RETURN LEAST(chemistry, 100);
END;
$$ LANGUAGE plpgsql;

-- Expire old market listings
CREATE OR REPLACE FUNCTION expire_market_listings()
RETURNS void AS $$
BEGIN
    UPDATE transfer_market
    SET status = 'expired'
    WHERE status = 'active' AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA: Pack Types
-- ============================================================

INSERT INTO pack_types (name, description, coin_cost, premium_cost, card_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, image_url) VALUES
('Bronze Pack', 'A basic pack with mostly bronze players', 500, 0, 3, 70.00, 22.00, 6.00, 1.50, 0.50, 'bronze_pack.png'),
('Silver Pack', 'Contains silver or better players', 1500, 0, 4, 30.00, 45.00, 18.00, 5.00, 2.00, 'silver_pack.png'),
('Gold Pack', 'Premium pack with gold guaranteed', 5000, 0, 5, 10.00, 25.00, 40.00, 18.00, 7.00, 'gold_pack.png'),
('Elite Pack', 'Rare pack with elite chance', 0, 100, 5, 5.00, 15.00, 35.00, 30.00, 15.00, 'elite_pack.png'),
('Legend Pack', 'Ultimate pack featuring legends', 0, 250, 5, 0.00, 5.00, 25.00, 40.00, 30.00, 'legend_pack.png');

-- ============================================================
-- SEED DATA: Player Cards
-- ============================================================

INSERT INTO player_cards (player_name, country, league, team, role, rating, batting, bowling, fielding, stamina, pace, spin, rarity, card_type) VALUES
-- Legend-tier
('Sachin Tendulkar', 'India', 'IPL', 'Mumbai Indians', 'batsman', 97, 99, 30, 85, 80, 50, 50, 'legend', 'icon'),
('Sir Don Bradman', 'Australia', NULL, NULL, 'batsman', 99, 99, 20, 70, 75, 50, 50, 'legend', 'icon'),
('Shane Warne', 'Australia', NULL, NULL, 'bowler', 96, 40, 98, 75, 85, 30, 99, 'legend', 'icon'),
('Wasim Akram', 'Pakistan', NULL, NULL, 'bowler', 95, 55, 97, 70, 85, 98, 40, 'legend', 'icon'),
('Jacques Kallis', 'South Africa', NULL, NULL, 'all_rounder', 96, 93, 88, 90, 90, 80, 50, 'legend', 'icon'),
('Adam Gilchrist', 'Australia', NULL, NULL, 'wicket_keeper', 94, 91, 20, 95, 85, 50, 50, 'legend', 'icon'),
('Brian Lara', 'West Indies', NULL, NULL, 'batsman', 96, 98, 15, 80, 82, 50, 50, 'legend', 'icon'),
('Muttiah Muralitharan', 'Sri Lanka', NULL, NULL, 'bowler', 96, 25, 99, 65, 90, 30, 99, 'legend', 'icon'),

-- Elite-tier
('Virat Kohli', 'India', 'IPL', 'Royal Challengers', 'batsman', 92, 96, 15, 90, 88, 50, 50, 'elite', 'standard'),
('Kane Williamson', 'New Zealand', 'IPL', 'Gujarat Titans', 'batsman', 89, 92, 25, 85, 82, 50, 50, 'elite', 'standard'),
('Pat Cummins', 'Australia', 'IPL', 'Sunrisers', 'bowler', 90, 45, 94, 75, 90, 95, 30, 'elite', 'standard'),
('Jasprit Bumrah', 'India', 'IPL', 'Mumbai Indians', 'bowler', 91, 15, 96, 70, 88, 97, 25, 'elite', 'standard'),
('Ben Stokes', 'England', 'IPL', 'Chennai Super Kings', 'all_rounder', 89, 86, 82, 88, 85, 85, 40, 'elite', 'standard'),
('Rashid Khan', 'Afghanistan', 'IPL', 'Gujarat Titans', 'bowler', 90, 50, 93, 80, 88, 50, 97, 'elite', 'standard'),
('Jos Buttler', 'England', 'IPL', 'Rajasthan Royals', 'wicket_keeper', 88, 90, 10, 92, 85, 50, 50, 'elite', 'standard'),
('Shaheen Afridi', 'Pakistan', 'PSL', 'Lahore Qalandars', 'bowler', 88, 20, 92, 65, 87, 96, 20, 'elite', 'standard'),

-- Gold-tier
('Rohit Sharma', 'India', 'IPL', 'Mumbai Indians', 'batsman', 87, 91, 15, 75, 78, 50, 50, 'gold', 'standard'),
('Steve Smith', 'Australia', 'IPL', 'Delhi Capitals', 'batsman', 86, 90, 20, 80, 80, 50, 50, 'gold', 'standard'),
('Babar Azam', 'Pakistan', 'PSL', 'Karachi Kings', 'batsman', 87, 92, 10, 82, 80, 50, 50, 'gold', 'standard'),
('Trent Boult', 'New Zealand', 'IPL', 'Rajasthan Royals', 'bowler', 85, 25, 90, 70, 85, 93, 25, 'gold', 'standard'),
('Kagiso Rabada', 'South Africa', 'IPL', 'Punjab Kings', 'bowler', 86, 20, 91, 65, 87, 95, 20, 'gold', 'standard'),
('Shakib Al Hasan', 'Bangladesh', 'BPL', 'Dhaka Dynamites', 'all_rounder', 84, 82, 85, 78, 82, 60, 88, 'gold', 'standard'),
('Quinton de Kock', 'South Africa', 'IPL', 'Lucknow Super Giants', 'wicket_keeper', 84, 86, 10, 90, 80, 50, 50, 'gold', 'standard'),
('KL Rahul', 'India', 'IPL', 'Lucknow Super Giants', 'wicket_keeper', 85, 89, 10, 85, 80, 50, 50, 'gold', 'standard'),
('David Warner', 'Australia', 'IPL', 'Delhi Capitals', 'batsman', 86, 90, 12, 80, 82, 50, 50, 'gold', 'standard'),
('Mitchell Starc', 'Australia', 'BBL', 'Sydney Sixers', 'bowler', 87, 35, 92, 70, 85, 97, 20, 'gold', 'standard'),
('Ravindra Jadeja', 'India', 'IPL', 'Chennai Super Kings', 'all_rounder', 85, 78, 86, 95, 88, 55, 90, 'gold', 'standard'),
('Joe Root', 'England', 'CPL', NULL, 'batsman', 86, 92, 30, 82, 85, 50, 55, 'gold', 'standard'),

-- Silver-tier
('Shreyas Iyer', 'India', 'IPL', 'Kolkata Knight Riders', 'batsman', 80, 83, 10, 78, 78, 50, 50, 'silver', 'standard'),
('Mitchell Marsh', 'Australia', 'IPL', 'Delhi Capitals', 'all_rounder', 79, 78, 75, 75, 80, 82, 40, 'silver', 'standard'),
('Sanju Samson', 'India', 'IPL', 'Rajasthan Royals', 'wicket_keeper', 79, 82, 5, 85, 78, 50, 50, 'silver', 'standard'),
('Mohammad Siraj', 'India', 'IPL', 'Royal Challengers', 'bowler', 80, 10, 85, 60, 85, 90, 20, 'silver', 'standard'),
('Yuzvendra Chahal', 'India', 'IPL', 'Rajasthan Royals', 'bowler', 78, 15, 86, 55, 80, 30, 92, 'silver', 'standard'),
('Devon Conway', 'New Zealand', 'IPL', 'Chennai Super Kings', 'batsman', 78, 84, 5, 78, 78, 50, 50, 'silver', 'standard'),
('Wanindu Hasaranga', 'Sri Lanka', 'IPL', 'Royal Challengers', 'all_rounder', 80, 60, 85, 75, 82, 50, 93, 'silver', 'standard'),
('Fakhar Zaman', 'Pakistan', 'PSL', 'Lahore Qalandars', 'batsman', 79, 83, 5, 75, 78, 50, 50, 'silver', 'standard'),
('Marco Jansen', 'South Africa', 'IPL', 'Sunrisers', 'bowler', 78, 40, 83, 65, 82, 90, 25, 'silver', 'standard'),
('Kuldeep Yadav', 'India', 'IPL', 'Delhi Capitals', 'bowler', 79, 15, 84, 60, 80, 30, 91, 'silver', 'standard'),

-- Bronze-tier
('Ishan Kishan', 'India', 'IPL', 'Mumbai Indians', 'wicket_keeper', 74, 78, 5, 80, 75, 50, 50, 'bronze', 'standard'),
('Rahmanullah Gurbaz', 'Afghanistan', 'IPL', 'Kolkata Knight Riders', 'wicket_keeper', 73, 77, 5, 78, 75, 50, 50, 'bronze', 'standard'),
('Finn Allen', 'New Zealand', 'BBL', NULL, 'batsman', 72, 76, 5, 72, 75, 50, 50, 'bronze', 'standard'),
('Haris Rauf', 'Pakistan', 'PSL', 'Lahore Qalandars', 'bowler', 74, 10, 80, 55, 80, 92, 20, 'bronze', 'standard'),
('Shardul Thakur', 'India', 'IPL', 'Kolkata Knight Riders', 'all_rounder', 73, 60, 76, 65, 78, 85, 30, 'bronze', 'standard'),
('Deepak Chahar', 'India', 'IPL', 'Chennai Super Kings', 'bowler', 74, 50, 78, 60, 78, 88, 30, 'bronze', 'standard'),
('Avesh Khan', 'India', 'IPL', 'Lucknow Super Giants', 'bowler', 72, 10, 77, 55, 80, 90, 20, 'bronze', 'standard'),
('Tilak Varma', 'India', 'IPL', 'Mumbai Indians', 'batsman', 73, 78, 20, 72, 78, 50, 50, 'bronze', 'standard'),
('Pathum Nissanka', 'Sri Lanka', 'LPL', NULL, 'batsman', 74, 80, 5, 75, 78, 50, 50, 'bronze', 'standard'),
('Josh Hazlewood', 'Australia', 'IPL', 'Royal Challengers', 'bowler', 75, 15, 82, 65, 82, 88, 20, 'bronze', 'standard'),
('Gerald Coetzee', 'South Africa', 'IPL', 'Mumbai Indians', 'bowler', 71, 20, 76, 60, 80, 92, 15, 'bronze', 'standard'),
('Rachin Ravindra', 'New Zealand', 'IPL', 'Chennai Super Kings', 'all_rounder', 72, 75, 65, 72, 78, 50, 70, 'bronze', 'standard');
