-- Allow cross-user reading of squads, squad_players, and user_cards
-- Required for multiplayer: the simulator needs to load both teams' lineups.

-- Squads: allow any authenticated user to view any squad
CREATE POLICY "Authenticated users can view all squads"
  ON squads FOR SELECT
  USING (auth.role() = 'authenticated');

-- Squad players: allow any authenticated user to view any squad player
CREATE POLICY "Authenticated users can view all squad players"
  ON squad_players FOR SELECT
  USING (auth.role() = 'authenticated');

-- User cards: allow any authenticated user to view any user card
-- (needed for nested joins when loading opponent team data)
CREATE POLICY "Authenticated users can view all user cards"
  ON user_cards FOR SELECT
  USING (auth.role() = 'authenticated');
