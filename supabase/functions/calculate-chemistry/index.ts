import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SquadPlayer {
  user_card_id: string;
  position: number;
  is_captain: boolean;
  is_vice_captain: boolean;
  user_cards: {
    id: string;
    level: number;
    form: number;
    fatigue: number;
    player_cards: {
      player_name: string;
      rating: number;
      batting: number;
      bowling: number;
      fielding: number;
      pace: number;
      spin: number;
      stamina: number;
      role: string;
      country: string;
      team: string | null;
      league: string | null;
    };
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { squad_id } = await req.json();
    if (!squad_id) {
      return new Response(JSON.stringify({ error: "squad_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get squad players
    const { data: squadPlayers, error: squadError } = await supabase
      .from("squad_players")
      .select(`
        user_card_id,
        position,
        is_captain,
        is_vice_captain,
        user_cards(
          id, level, form, fatigue,
          player_cards(
            player_name, rating, batting, bowling, fielding,
            pace, spin, stamina, role, country, team, league
          )
        )
      `)
      .eq("squad_id", squad_id)
      .lte("position", 11);

    if (squadError || !squadPlayers) {
      return new Response(JSON.stringify({ error: "Squad not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const players = squadPlayers as unknown as SquadPlayer[];

    // Calculate chemistry bonuses
    let totalChemistry = 0;
    const maxChemistry = 100;

    // 1. Country links (same country pairs)
    const countries = players.map((p) => p.user_cards.player_cards.country);
    const countryGroups: Record<string, number> = {};
    for (const c of countries) {
      countryGroups[c] = (countryGroups[c] || 0) + 1;
    }
    for (const count of Object.values(countryGroups)) {
      if (count >= 2) totalChemistry += count * 3; // 3 pts per same-country player
    }

    // 2. Team links (same club/franchise)
    const teams = players
      .map((p) => p.user_cards.player_cards.team)
      .filter(Boolean) as string[];
    const teamGroups: Record<string, number> = {};
    for (const t of teams) {
      teamGroups[t] = (teamGroups[t] || 0) + 1;
    }
    for (const count of Object.values(teamGroups)) {
      if (count >= 2) totalChemistry += count * 4; // 4 pts per same-team player
    }

    // 3. League links
    const leagues = players
      .map((p) => p.user_cards.player_cards.league)
      .filter(Boolean) as string[];
    const leagueGroups: Record<string, number> = {};
    for (const l of leagues) {
      leagueGroups[l] = (leagueGroups[l] || 0) + 1;
    }
    for (const count of Object.values(leagueGroups)) {
      if (count >= 2) totalChemistry += count * 2; // 2 pts per same-league player
    }

    // 4. Role balance bonus
    const roles = players.map((p) => p.user_cards.player_cards.role);
    const hasBatsman = roles.some((r) => r === "batsman");
    const hasBowler = roles.some((r) => r === "bowler" || r === "pace_bowler" || r === "spin_bowler");
    const hasAllRounder = roles.some((r) => r === "all_rounder");
    const hasKeeper = roles.some((r) => r === "wicket_keeper");

    if (hasBatsman && hasBowler) totalChemistry += 5;
    if (hasAllRounder) totalChemistry += 3;
    if (hasKeeper) totalChemistry += 2;

    // Cap at max
    totalChemistry = Math.min(totalChemistry, maxChemistry);

    // Build breakdown
    const breakdown = {
      country_links: Object.entries(countryGroups)
        .filter(([, c]) => c >= 2)
        .map(([country, count]) => ({ country, count, bonus: count * 3 })),
      team_links: Object.entries(teamGroups)
        .filter(([, c]) => c >= 2)
        .map(([team, count]) => ({ team, count, bonus: count * 4 })),
      league_links: Object.entries(leagueGroups)
        .filter(([, c]) => c >= 2)
        .map(([league, count]) => ({ league, count, bonus: count * 2 })),
      role_balance: {
        has_batsman: hasBatsman,
        has_bowler: hasBowler,
        has_all_rounder: hasAllRounder,
        has_keeper: hasKeeper,
        bonus: (hasBatsman && hasBowler ? 5 : 0) + (hasAllRounder ? 3 : 0) + (hasKeeper ? 2 : 0),
      },
    };

    return new Response(
      JSON.stringify({
        chemistry: totalChemistry,
        max_chemistry: maxChemistry,
        breakdown,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
