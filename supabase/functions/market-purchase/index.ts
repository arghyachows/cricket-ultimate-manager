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

    const { listing_id, action } = await req.json();

    if (!listing_id || !action) {
      return new Response(JSON.stringify({ error: "listing_id and action required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get listing
    const { data: listing, error: listingError } = await supabase
      .from("transfer_market")
      .select("*, user_cards(*, player_cards(*))")
      .eq("id", listing_id)
      .eq("status", "active")
      .single();

    if (listingError || !listing) {
      return new Response(JSON.stringify({ error: "Listing not found or expired" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (listing.seller_id === user.id) {
      return new Response(JSON.stringify({ error: "Cannot buy your own listing" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check expiry
    if (new Date(listing.expires_at) < new Date()) {
      await supabase
        .from("transfer_market")
        .update({ status: "expired" })
        .eq("id", listing_id);

      return new Response(JSON.stringify({ error: "Listing has expired" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: buyer, error: buyerError } = await supabase
      .from("users")
      .select("coins")
      .eq("id", user.id)
      .single();

    if (buyerError || !buyer) {
      return new Response(JSON.stringify({ error: "Buyer not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "buy_now") {
      const price = listing.buy_now_price;

      if (buyer.coins < price) {
        return new Response(JSON.stringify({ error: "Insufficient coins" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Transfer card
      await supabase
        .from("user_cards")
        .update({ user_id: user.id, is_tradeable: true })
        .eq("id", listing.user_card_id);

      // Deduct from buyer
      await supabase
        .from("users")
        .update({ coins: buyer.coins - price })
        .eq("id", user.id);

      // Pay seller (5% market tax)
      const sellerPayout = Math.floor(price * 0.95);
      const { data: seller } = await supabase
        .from("users")
        .select("coins")
        .eq("id", listing.seller_id)
        .single();

      if (seller) {
        await supabase
          .from("users")
          .update({ coins: seller.coins + sellerPayout })
          .eq("id", listing.seller_id);
      }

      // Close listing
      await supabase
        .from("transfer_market")
        .update({
          status: "sold",
          buyer_id: user.id,
          sold_price: price,
        })
        .eq("id", listing_id);

      // Record transactions
      await supabase.from("transactions").insert([
        {
          user_id: user.id,
          type: "market_purchase",
          amount: -price,
          currency: "coins",
          description: `Bought ${listing.user_cards?.player_cards?.player_name ?? "card"} from market`,
        },
        {
          user_id: listing.seller_id,
          type: "market_sale",
          amount: sellerPayout,
          currency: "coins",
          description: `Sold ${listing.user_cards?.player_cards?.player_name ?? "card"} on market (5% tax)`,
        },
      ]);

      return new Response(
        JSON.stringify({
          success: true,
          message: "Purchase complete",
          card: listing.user_cards,
          price,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (action === "bid") {
      const { bid_amount } = await req.json();
      const minBid = listing.current_bid > 0
        ? listing.current_bid + Math.max(100, Math.floor(listing.current_bid * 0.05))
        : listing.starting_bid;

      if (!bid_amount || bid_amount < minBid) {
        return new Response(
          JSON.stringify({ error: `Minimum bid is ${minBid} coins` }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      if (buyer.coins < bid_amount) {
        return new Response(JSON.stringify({ error: "Insufficient coins" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      await supabase
        .from("transfer_market")
        .update({
          current_bid: bid_amount,
          buyer_id: user.id,
        })
        .eq("id", listing_id);

      return new Response(
        JSON.stringify({ success: true, message: "Bid placed", bid_amount }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: "Invalid action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
