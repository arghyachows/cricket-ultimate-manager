import "https://deno.land/x/xhr@0.3.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PackConfig {
  id: string;
  name: string;
  rarity_weights: Record<string, number>;
  card_count: number;
  guaranteed_rarity: string | null;
  cost_coins: number;
  cost_premium: number;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Authenticate user
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

    const { pack_type_id } = await req.json();
    if (!pack_type_id) {
      return new Response(JSON.stringify({ error: "pack_type_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get pack config
    const { data: packType, error: packError } = await supabase
      .from("pack_types")
      .select("*")
      .eq("id", pack_type_id)
      .single();

    if (packError || !packType) {
      return new Response(JSON.stringify({ error: "Pack type not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const pack = packType as PackConfig;

    // Check user balance
    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("coins, premium_tokens")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const usePremium = pack.cost_premium > 0 && pack.cost_coins === 0;
    if (usePremium && userData.premium_tokens < pack.cost_premium) {
      return new Response(JSON.stringify({ error: "Insufficient premium tokens" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!usePremium && userData.coins < pack.cost_coins) {
      return new Response(JSON.stringify({ error: "Insufficient coins" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Generate cards using weighted random selection
    const rarityWeights = pack.rarity_weights;
    const cardCount = pack.card_count;
    const guaranteedRarity = pack.guaranteed_rarity;

    const selectedRarities: string[] = [];
    for (let i = 0; i < cardCount; i++) {
      // Last card uses guaranteed rarity if specified
      if (i === cardCount - 1 && guaranteedRarity) {
        selectedRarities.push(guaranteedRarity);
      } else {
        selectedRarities.push(weightedRandomRarity(rarityWeights));
      }
    }

    // Fetch random cards for each rarity
    const generatedCards: any[] = [];
    for (const rarity of selectedRarities) {
      const { data: cards, error: cardError } = await supabase
        .from("player_cards")
        .select("*")
        .eq("rarity", rarity)
        .eq("is_active", true);

      if (cardError || !cards || cards.length === 0) continue;

      const randomCard = cards[Math.floor(Math.random() * cards.length)];
      generatedCards.push(randomCard);
    }

    if (generatedCards.length === 0) {
      return new Response(JSON.stringify({ error: "No cards could be generated" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Create user_cards entries
    const userCards = generatedCards.map((card) => ({
      user_id: user.id,
      player_card_id: card.id,
      acquired_via: "pack",
      is_tradeable: true,
    }));

    const { data: insertedCards, error: insertError } = await supabase
      .from("user_cards")
      .insert(userCards)
      .select("*, player_cards(*)");

    if (insertError) {
      return new Response(JSON.stringify({ error: "Failed to create cards" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Deduct cost
    if (usePremium) {
      await supabase
        .from("users")
        .update({ premium_tokens: userData.premium_tokens - pack.cost_premium })
        .eq("id", user.id);
    } else {
      await supabase
        .from("users")
        .update({ coins: userData.coins - pack.cost_coins })
        .eq("id", user.id);
    }

    // Record pack opening
    await supabase
      .from("pack_openings")
      .insert({
        user_id: user.id,
        pack_type_id: pack_type_id,
        cards_received: insertedCards.map((c: any) => c.id),
      });

    // Record transaction
    await supabase.from("transactions").insert({
      user_id: user.id,
      type: "pack_purchase",
      amount: usePremium ? -pack.cost_premium : -pack.cost_coins,
      currency: usePremium ? "premium" : "coins",
      description: `Opened ${pack.name}`,
    });

    return new Response(
      JSON.stringify({
        cards: insertedCards,
        pack_name: pack.name,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function weightedRandomRarity(weights: Record<string, number>): string {
  const entries = Object.entries(weights);
  const totalWeight = entries.reduce((sum, [, w]) => sum + w, 0);
  let random = Math.random() * totalWeight;

  for (const [rarity, weight] of entries) {
    random -= weight;
    if (random <= 0) return rarity;
  }

  return entries[entries.length - 1][0];
}
