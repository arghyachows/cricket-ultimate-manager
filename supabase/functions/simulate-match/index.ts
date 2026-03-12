import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface BallOutcome {
  runs: number;
  is_wicket: boolean;
  is_extra: boolean;
  extra_type?: string;
  commentary: string;
}

interface InningsState {
  runs: number;
  wickets: number;
  overs: number;
  balls: number;
  batting_team: string;
  bowling_team: string;
  current_batsman_idx: number;
  current_bowler_idx: number;
  events: any[];
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

    const { match_id, format = "t20" } = await req.json();
    if (!match_id) {
      return new Response(JSON.stringify({ error: "match_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const maxOvers = format === "t20" ? 20 : format === "odi" ? 50 : 5;

    // Get match data
    const { data: match, error: matchError } = await supabase
      .from("matches")
      .select("*")
      .eq("id", match_id)
      .single();

    if (matchError || !match) {
      return new Response(JSON.stringify({ error: "Match not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update match to in_progress
    await supabase
      .from("matches")
      .update({ status: "in_progress" })
      .eq("id", match_id);

    // Simulate both innings
    const firstInnings = simulateInnings(maxOvers, 80, 75); // team1 batting, team2 bowling
    const target = firstInnings.runs + 1;
    const secondInnings = simulateInnings(maxOvers, 75, 80, target); // team2 batting, team1 bowling

    // Determine result
    let result: string;
    let winnerId: string | null = null;

    if (secondInnings.runs >= target) {
      result = `Team 2 wins by ${10 - secondInnings.wickets} wickets`;
      winnerId = match.team2_id;
    } else if (secondInnings.runs < firstInnings.runs) {
      result = `Team 1 wins by ${firstInnings.runs - secondInnings.runs} runs`;
      winnerId = match.team1_id;
    } else {
      result = "Match tied";
    }

    // Store events
    const allEvents = [
      ...firstInnings.events.map((e: any, i: number) => ({
        match_id,
        innings: 1,
        over_number: e.over,
        ball_number: e.ball,
        runs_scored: e.runs,
        is_wicket: e.is_wicket,
        is_extra: e.is_extra,
        extra_type: e.extra_type || null,
        commentary: e.commentary,
        event_order: i,
      })),
      ...secondInnings.events.map((e: any, i: number) => ({
        match_id,
        innings: 2,
        over_number: e.over,
        ball_number: e.ball,
        runs_scored: e.runs,
        is_wicket: e.is_wicket,
        is_extra: e.is_extra,
        extra_type: e.extra_type || null,
        commentary: e.commentary,
        event_order: firstInnings.events.length + i,
      })),
    ];

    // Insert in batches
    for (let i = 0; i < allEvents.length; i += 50) {
      const batch = allEvents.slice(i, i + 50);
      await supabase.from("match_events").insert(batch);
    }

    // Update match result
    await supabase
      .from("matches")
      .update({
        status: "completed",
        team1_score: firstInnings.runs,
        team1_wickets: firstInnings.wickets,
        team1_overs: firstInnings.overs + firstInnings.balls / 10,
        team2_score: secondInnings.runs,
        team2_wickets: secondInnings.wickets,
        team2_overs: secondInnings.overs + secondInnings.balls / 10,
        winner_id: winnerId,
        result,
      })
      .eq("id", match_id);

    // Award coins
    if (winnerId) {
      const winnerUserId = match.team1_id === winnerId
        ? match.user1_id
        : match.user2_id;

      if (winnerUserId) {
        const { data: winner } = await supabase
          .from("users")
          .select("coins, xp, matches_won, matches_played")
          .eq("id", winnerUserId)
          .single();

        if (winner) {
          await supabase
            .from("users")
            .update({
              coins: winner.coins + 500,
              xp: winner.xp + 100,
              matches_won: (winner.matches_won || 0) + 1,
              matches_played: (winner.matches_played || 0) + 1,
            })
            .eq("id", winnerUserId);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        result,
        first_innings: { runs: firstInnings.runs, wickets: firstInnings.wickets, overs: `${firstInnings.overs}.${firstInnings.balls}` },
        second_innings: { runs: secondInnings.runs, wickets: secondInnings.wickets, overs: `${secondInnings.overs}.${secondInnings.balls}` },
        total_events: allEvents.length,
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

function simulateInnings(
  maxOvers: number,
  battingStrength: number,
  bowlingStrength: number,
  target?: number
): InningsState {
  const state: InningsState = {
    runs: 0,
    wickets: 0,
    overs: 0,
    balls: 0,
    batting_team: "",
    bowling_team: "",
    current_batsman_idx: 0,
    current_bowler_idx: 0,
    events: [],
  };

  const batMod = (battingStrength - 75) / 100;
  const bowlMod = (bowlingStrength - 75) / 100;

  while (state.overs < maxOvers && state.wickets < 10) {
    if (target && state.runs >= target) break;

    const outcome = generateBall(batMod, bowlMod);

    state.events.push({
      over: state.overs,
      ball: state.balls + 1,
      runs: outcome.runs,
      is_wicket: outcome.is_wicket,
      is_extra: outcome.is_extra,
      extra_type: outcome.extra_type,
      commentary: outcome.commentary,
    });

    state.runs += outcome.runs;
    if (outcome.is_wicket) state.wickets++;

    if (!outcome.is_extra) {
      state.balls++;
      if (state.balls >= 6) {
        state.overs++;
        state.balls = 0;
      }
    }
  }

  return state;
}

function generateBall(batMod: number, bowlMod: number): BallOutcome {
  const r = Math.random();

  // Base probabilities adjusted by team strengths
  const dotProb = 0.35 - batMod * 0.1 + bowlMod * 0.1;
  const singleProb = dotProb + 0.30;
  const doubleProb = singleProb + 0.12;
  const tripleProb = doubleProb + 0.02;
  const fourProb = tripleProb + 0.10 + batMod * 0.05;
  const sixProb = fourProb + 0.04 + batMod * 0.03;
  const wicketProb = sixProb + 0.05 + bowlMod * 0.03;

  if (r < dotProb) {
    return { runs: 0, is_wicket: false, is_extra: false, commentary: "Dot ball, well bowled!" };
  } else if (r < singleProb) {
    return { runs: 1, is_wicket: false, is_extra: false, commentary: "Quick single taken" };
  } else if (r < doubleProb) {
    return { runs: 2, is_wicket: false, is_extra: false, commentary: "Nicely placed for two runs" };
  } else if (r < tripleProb) {
    return { runs: 3, is_wicket: false, is_extra: false, commentary: "Good running between the wickets, three taken" };
  } else if (r < fourProb) {
    return { runs: 4, is_wicket: false, is_extra: false, commentary: "FOUR! Cracking shot to the boundary!" };
  } else if (r < sixProb) {
    return { runs: 6, is_wicket: false, is_extra: false, commentary: "SIX! Massive hit, out of the ground!" };
  } else if (r < wicketProb) {
    return { runs: 0, is_wicket: true, is_extra: false, commentary: "OUT! The bowler strikes!" };
  } else {
    const isWide = Math.random() > 0.5;
    return {
      runs: 1,
      is_wicket: false,
      is_extra: true,
      extra_type: isWide ? "wide" : "no_ball",
      commentary: isWide ? "Wide ball, extra run" : "No ball called, free hit coming up",
    };
  }
}
