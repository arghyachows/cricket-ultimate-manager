import { MatchEngine } from './match-engine.js';

export class MatchSimulator {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.engine = null;
    this.matchId = null;
    this.isSimulating = false;
    this.isQuickMatch = false;
    this.commentaryLog = [];
  }

  async fetch(request) {
    const url = new URL(request.url);
    
    switch (url.pathname) {
      case '/start':
        return this.handleStart(request);
      case '/start-quick':
        return this.handleStartQuick(request);
      case '/state':
        return this.handleGetState(request);
      case '/stop':
        return this.handleStop(request);
      default:
        return new Response('Not found', { status: 404 });
    }
  }

  async handleStart(request) {
    if (this.isSimulating) {
      return new Response(JSON.stringify({ error: 'Match already simulating' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const body = await request.json();
    this.matchId = body.matchId;

    // Load match data from Supabase
    const matchData = await this.loadMatchFromSupabase(this.matchId);
    if (!matchData) {
      return new Response(JSON.stringify({ error: 'Match not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Load teams
    const homeXI = await this.loadTeamXI(matchData.home_team_id);
    const awayXI = await this.loadTeamXI(matchData.away_team_id);

    // Initialize engine
    this.engine = new MatchEngine({
      homeXI,
      awayXI,
      homeChemistry: matchData.home_chemistry ?? 50,
      awayChemistry: matchData.away_chemistry ?? 50,
      maxOvers: matchData.match_overs ?? 20,
      pitchCondition: matchData.pitch_condition ?? 'balanced',
      homeTeamName: matchData.home_team_name ?? 'Home',
      awayTeamName: matchData.away_team_name ?? 'Away',
      homeBatsFirst: matchData.home_bats_first ?? true,
      env: this.env,
      useAICommentary: true,
    });

    this.commentaryLog = [];
    this.isSimulating = true;

    // Persist initial state
    await this.state.storage.put('engine', this.engine.serialize());
    await this.state.storage.put('matchId', this.matchId);
    await this.state.storage.put('commentaryLog', this.commentaryLog);

    // Start simulation in background (no await - fire and forget)
    this.runSimulation();

    return new Response(JSON.stringify({ success: true, matchId: this.matchId }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  async handleStartQuick(request) {
    if (this.isSimulating) {
      return new Response(JSON.stringify({ error: 'Match already simulating' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const body = await request.json();
    this.matchId = body.matchId;
    const config = body.config;

    // For quick matches, config contains all match data
    // No need to load from Supabase
    this.engine = new MatchEngine({
      homeXI: config.homeXI,
      awayXI: config.awayXI,
      homeChemistry: config.homeChemistry ?? 50,
      awayChemistry: config.awayChemistry ?? 50,
      maxOvers: config.maxOvers ?? 20,
      pitchCondition: config.pitchCondition ?? 'balanced',
      homeTeamName: config.homeTeamName ?? 'Home',
      awayTeamName: config.awayTeamName ?? 'Away',
      homeBatsFirst: config.homeBatsFirst ?? true,
      env: this.env,
      useAICommentary: true,
    });

    this.commentaryLog = [];
    this.isSimulating = true;
    this.isQuickMatch = true;

    // Persist initial state
    await this.state.storage.put('engine', this.engine.serialize());
    await this.state.storage.put('matchId', this.matchId);
    await this.state.storage.put('commentaryLog', this.commentaryLog);
    await this.state.storage.put('isQuickMatch', true);

    // Start simulation in background (no await - fire and forget)
    this.runSimulationQuick();

    return new Response(JSON.stringify({ success: true, matchId: this.matchId }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  async handleGetState(request) {
    if (!this.engine) {
      // Try to restore from storage
      const engineData = await this.state.storage.get('engine');
      if (engineData) {
        this.engine = MatchEngine.deserialize(engineData);
        this.matchId = await this.state.storage.get('matchId');
        this.commentaryLog = await this.state.storage.get('commentaryLog') || [];
      } else {
        return new Response(JSON.stringify({ error: 'No active match' }), {
          status: 404,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    }

    return new Response(JSON.stringify({
      matchId: this.matchId,
      isSimulating: this.isSimulating,
      matchComplete: this.engine.matchComplete,
      innings: this.engine.innings,
      score1: this.engine.score1,
      wickets1: this.engine.wickets1,
      score2: this.engine.score2,
      wickets2: this.engine.wickets2,
      overNumber: this.engine.overNumber,
      ballNumber: this.engine.ballNumber,
      target: this.engine.target,
      batsmanStats: this.engine.batsmanStats,
      bowlerStats: this.engine.bowlerStats,
      commentaryLog: this.commentaryLog,
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  async handleStop(request) {
    this.isSimulating = false;
    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  async runSimulation() {
    let ballCount = 0;

    while (!this.engine.matchComplete && this.isSimulating) {
      const result = await this.engine.simulateNextBall();
      if (!result) break;

      ballCount++;

      // Calculate display values
      const hScore = this.engine.homeBatsFirst ? this.engine.score1 : this.engine.score2;
      const hWickets = this.engine.homeBatsFirst ? this.engine.wickets1 : this.engine.wickets2;
      const aScore = this.engine.homeBatsFirst ? this.engine.score2 : this.engine.score1;
      const aWickets = this.engine.homeBatsFirst ? this.engine.wickets2 : this.engine.wickets1;

      const hOversDisplay = this.engine.homeBatsFirst
        ? (result.innings === 1 ? `${result.overNumber}.${result.ballNumber}` : this.oversDisplay(this.engine.maxOvers * 6))
        : (result.innings === 2 ? `${result.overNumber}.${result.ballNumber}` : '0.0');
      
      const aOversDisplay = !this.engine.homeBatsFirst
        ? (result.innings === 1 ? `${result.overNumber}.${result.ballNumber}` : this.oversDisplay(this.engine.maxOvers * 6))
        : (result.innings === 2 ? `${result.overNumber}.${result.ballNumber}` : '0.0');

      const currentOvers = result.innings === 1
        ? (this.engine.homeBatsFirst ? hOversDisplay : aOversDisplay)
        : (this.engine.homeBatsFirst ? aOversDisplay : hOversDisplay);

      // Add to commentary log
      this.commentaryLog.push({
        commentary: result.commentary,
        eventType: result.eventType,
        runs: result.runs,
        innings: result.innings,
        oversDisplay: currentOvers,
      });

      // Update Supabase
      await this.updateSupabase({
        home_score: hScore,
        home_wickets: hWickets,
        away_score: aScore,
        away_wickets: aWickets,
        current_innings: result.innings,
        current_commentary: result.commentary,
        home_overs_display: hOversDisplay,
        away_overs_display: aOversDisplay,
        last_event_type: result.eventType,
        last_runs: result.runs,
        target: this.engine.target,
        home_batsman: this.engine.currentBatsman.name,
        away_batsman: this.engine.nonStriker.name,
        current_bowler: this.engine.currentBowler.name,
        scorecard_data: {
          batsmen: this.engine.batsmanStats,
          bowlers: this.engine.bowlerStats,
        },
        commentary_log: this.commentaryLog,
      });

      // Persist state to Durable Object storage
      await this.state.storage.put('engine', this.engine.serialize());
      await this.state.storage.put('commentaryLog', this.commentaryLog);

      // Delay between balls
      await this.sleep(1000);

      if (ballCount % 30 === 0) {
        console.log(`Ball ${ballCount}: ${this.engine.score1}/${this.engine.wickets1} vs ${this.engine.score2}/${this.engine.wickets2}`);
      }
    }

    // Match complete
    this.isSimulating = false;
    const hScore = this.engine.homeBatsFirst ? this.engine.score1 : this.engine.score2;
    const hWickets = this.engine.homeBatsFirst ? this.engine.wickets1 : this.engine.wickets2;
    const aScore = this.engine.homeBatsFirst ? this.engine.score2 : this.engine.score1;
    const aWickets = this.engine.homeBatsFirst ? this.engine.wickets2 : this.engine.wickets1;

    let winnerId = null;
    if (hScore > aScore) {
      const matchData = await this.loadMatchFromSupabase(this.matchId);
      winnerId = matchData.home_user_id;
    } else if (aScore > hScore) {
      const matchData = await this.loadMatchFromSupabase(this.matchId);
      winnerId = matchData.away_user_id;
    }

    const matchResult = this.engine.getMatchResult();

    await this.updateSupabase({
      status: 'completed',
      home_score: hScore,
      home_wickets: hWickets,
      away_score: aScore,
      away_wickets: aWickets,
      match_result: matchResult,
      current_commentary: matchResult,
      winner_user_id: winnerId,
      target: this.engine.target,
      scorecard_data: {
        batsmen: this.engine.batsmanStats,
        bowlers: this.engine.bowlerStats,
      },
    });

    // Award rewards
    await this.awardRewards(winnerId);

    console.log(`Match ${this.matchId} completed: ${matchResult}`);
  }

  async runSimulationQuick() {
    let ballCount = 0;

    while (!this.engine.matchComplete && this.isSimulating) {
      const result = await this.engine.simulateNextBall();
      if (!result) break;

      ballCount++;

      // Add to commentary log
      this.commentaryLog.push({
        commentary: result.commentary,
        eventType: result.eventType,
        runs: result.runs,
        innings: result.innings,
        overNumber: result.overNumber,
        ballNumber: result.ballNumber,
      });

      // Persist state to Durable Object storage
      await this.state.storage.put('engine', this.engine.serialize());
      await this.state.storage.put('commentaryLog', this.commentaryLog);

      // Faster delay for quick matches (1000ms same as multiplayer)
      await this.sleep(1000);

      if (ballCount % 30 === 0) {
        console.log(`Quick Match Ball ${ballCount}: ${this.engine.score1}/${this.engine.wickets1} vs ${this.engine.score2}/${this.engine.wickets2}`);
      }
    }

    // Match complete
    this.isSimulating = false;
    const matchResult = this.engine.getMatchResult();

    console.log(`Quick Match ${this.matchId} completed: ${matchResult}`);
  }

  async loadMatchFromSupabase(matchId) {
    const response = await fetch(
      `${this.env.SUPABASE_URL}/rest/v1/multiplayer_matches?id=eq.${matchId}&select=*`,
      {
        headers: {
          'apikey': this.env.SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${this.env.SUPABASE_SERVICE_KEY}`,
        }
      }
    );
    const data = await response.json();
    return data[0] || null;
  }

  async loadTeamXI(teamId) {
    const response = await fetch(
      `${this.env.SUPABASE_URL}/rest/v1/teams?id=eq.${teamId}&select=*,squads(*,squad_players(*,user_cards(*,player_cards(*))))`,
      {
        headers: {
          'apikey': this.env.SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${this.env.SUPABASE_SERVICE_KEY}`,
        }
      }
    );
    const data = await response.json();
    
    if (!data[0]) return this.generateFallbackXI();

    const squads = data[0].squads ?? [];
    const squad = squads.find(s => s.is_active) ?? squads[0];
    if (!squad) return this.generateFallbackXI();

    const players = (squad.squad_players ?? [])
      .filter(sp => sp.is_playing_xi)
      .sort((a, b) => (a.batting_order ?? 0) - (b.batting_order ?? 0));

    if (players.length === 0) return this.generateFallbackXI();

    return players.slice(0, 11).map(sp => this.mapPlayer(sp));
  }

  mapPlayer(sp) {
    const uc = sp.user_cards ?? sp.user_card;
    const pc = uc?.player_cards ?? uc?.player_card;
    const batting = pc?.batting ?? 50;
    const bowling = pc?.bowling ?? 50;
    return {
      userCardId: sp.user_card_id ?? uc?.id ?? crypto.randomUUID(),
      name: pc?.player_name ?? 'Player',
      role: pc?.role ?? 'batsman',
      batting,
      bowling,
      fielding: pc?.fielding ?? 50,
      aggression: batting + (Math.random() * 20 - 10),
      technique: batting + (Math.random() * 15 - 7.5),
      power: batting + (Math.random() * 20 - 10),
      consistency: batting + (Math.random() * 15 - 7.5),
      pace: bowling + (Math.random() * 20 - 10),
      swing: bowling + (Math.random() * 15 - 7.5),
      accuracy: bowling + (Math.random() * 20 - 10),
      variations: bowling + (Math.random() * 15 - 7.5),
    };
  }

  generateFallbackXI() {
    const roles = ['batsman', 'batsman', 'batsman', 'batsman', 'wicket_keeper', 'all_rounder', 'all_rounder', 'bowler', 'bowler', 'bowler', 'bowler'];
    const names = ['A. Smith', 'B. Kumar', 'C. Williams', 'D. Sharma', 'E. Jones', 'F. Singh', 'G. Taylor', 'H. Patel', 'I. Anderson', 'J. Khan', 'K. Brown'];
    return roles.map((role, i) => {
      const batting = role === 'bowler' ? 35 : role === 'all_rounder' ? 55 : 65;
      const bowling = role === 'batsman' ? 25 : role === 'all_rounder' ? 55 : 70;
      return {
        userCardId: crypto.randomUUID(),
        name: names[i],
        role,
        batting,
        bowling,
        fielding: 50,
        aggression: batting + (Math.random() * 20 - 10),
        technique: batting + (Math.random() * 15 - 7.5),
        power: batting + (Math.random() * 20 - 10),
        consistency: batting + (Math.random() * 15 - 7.5),
        pace: bowling + (Math.random() * 20 - 10),
        swing: bowling + (Math.random() * 15 - 7.5),
        accuracy: bowling + (Math.random() * 20 - 10),
        variations: bowling + (Math.random() * 15 - 7.5),
      };
    });
  }

  async updateSupabase(updates) {
    await fetch(
      `${this.env.SUPABASE_URL}/rest/v1/multiplayer_matches?id=eq.${this.matchId}`,
      {
        method: 'PATCH',
        headers: {
          'apikey': this.env.SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${this.env.SUPABASE_SERVICE_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify(updates),
      }
    );
  }

  async awardRewards(winnerId) {
    const matchData = await this.loadMatchFromSupabase(this.matchId);
    const userIds = [matchData.home_user_id, matchData.away_user_id].filter(Boolean);

    for (const uid of userIds) {
      const isWinner = uid === winnerId;
      const isDraw = winnerId === null;
      const coins = isWinner ? 100 : isDraw ? 50 : 30;
      const xp = isWinner ? 50 : isDraw ? 30 : 20;

      // Fetch user
      const userResponse = await fetch(
        `${this.env.SUPABASE_URL}/rest/v1/users?id=eq.${uid}&select=*`,
        {
          headers: {
            'apikey': this.env.SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${this.env.SUPABASE_SERVICE_KEY}`,
          }
        }
      );
      const userData = await userResponse.json();
      const user = userData[0];
      if (!user) continue;

      const newXp = (user.xp ?? 0) + xp;
      const newLevel = Math.min(Math.floor(newXp / 500) + 1, 100);

      // Update user
      await fetch(
        `${this.env.SUPABASE_URL}/rest/v1/users?id=eq.${uid}`,
        {
          method: 'PATCH',
          headers: {
            'apikey': this.env.SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${this.env.SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: JSON.stringify({
            coins: (user.coins ?? 0) + coins,
            xp: newXp,
            level: newLevel,
            matches_played: (user.matches_played ?? 0) + 1,
            matches_won: isWinner ? (user.matches_won ?? 0) + 1 : (user.matches_won ?? 0),
            updated_at: new Date().toISOString(),
          }),
        }
      );
    }
  }

  oversDisplay(balls) {
    return `${Math.floor(balls / 6)}.${balls % 6}`;
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
