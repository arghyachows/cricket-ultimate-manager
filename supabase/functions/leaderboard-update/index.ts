import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    const { season_type = "weekly" } = await req.json().catch(() => ({}));

    // Calculate leaderboard from match results
    const { data: users, error } = await supabase
      .from("users")
      .select("id, username, level, season_tier, matches_won, matches_played, win_rate")
      .order("win_rate", { ascending: false })
      .order("matches_won", { ascending: false })
      .limit(100);

    if (error) {
      return new Response(JSON.stringify({ error: "Failed to fetch leaderboard" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Upsert leaderboard entries
    const leaderboardEntries = (users || []).map((u: any, index: number) => ({
      user_id: u.id,
      season_type,
      rank: index + 1,
      rating: Math.round((u.win_rate || 0) * 1000 + (u.matches_won || 0)),
      matches_played: u.matches_played || 0,
      matches_won: u.matches_won || 0,
    }));

    if (leaderboardEntries.length > 0) {
      const { error: upsertError } = await supabase
        .from("leaderboard")
        .upsert(leaderboardEntries, {
          onConflict: "user_id,season_type",
        });

      if (upsertError) {
        console.error("Leaderboard upsert error:", upsertError);
      }
    }

    // Update season tiers based on rank
    for (const entry of leaderboardEntries) {
      let tier = "bronze";
      if (entry.rank <= 5) tier = "legend";
      else if (entry.rank <= 15) tier = "elite";
      else if (entry.rank <= 30) tier = "gold";
      else if (entry.rank <= 60) tier = "silver";

      await supabase
        .from("users")
        .update({ season_tier: tier })
        .eq("id", entry.user_id);
    }

    return new Response(
      JSON.stringify({
        success: true,
        entries: leaderboardEntries.length,
        top_player: leaderboardEntries[0] || null,
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
