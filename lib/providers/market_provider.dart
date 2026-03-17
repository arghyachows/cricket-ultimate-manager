import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'cards_provider.dart';

// ─── Active market listings ───────────────────────────────────────
final marketListingsProvider = StateNotifierProvider<MarketNotifier,
    AsyncValue<List<MarketListing>>>((ref) {
  return MarketNotifier(ref);
});

class MarketNotifier extends StateNotifier<AsyncValue<List<MarketListing>>> {
  final Ref ref;
  RealtimeChannel? _channel;

  MarketNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadListings();
    _subscribeToUpdates();
  }

  Future<void> loadListings() async {
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final data = await SupabaseService.getMarketListings();
      final listings =
          data.map((json) => MarketListing.fromJson(json)).toList();

      // Auto-settle any expired listings client sees
      for (final l in listings) {
        if (l.hasExpired && l.isActive) {
          _settleExpired(l.id);
        }
      }

      // Only show non-expired active listings
      final active = listings.where((l) => l.isActive && !l.hasExpired).toList();
      state = AsyncValue.data(active);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.subscribeToMarket((update) {
      loadListings();
      // Cascade refresh so users see real-time bid updates, outbid status, coin changes
      ref.read(myBidsProvider.notifier).load();
      ref.read(myListingsProvider.notifier).load();
      ref.read(currentUserProvider.notifier).silentRefresh();
    });
  }

  /// List a card for auction
  Future<bool> listCard({
    required String userCardId,
    required int buyNowPrice,
    required int startingBid,
    int durationHours = 24,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      // Mark card as not tradeable while listed
      await SupabaseService.client
          .from('user_cards')
          .update({'is_tradeable': false})
          .eq('id', userCardId);

      await SupabaseService.client.from('transfer_market').insert({
        'seller_id': userId,
        'user_card_id': userCardId,
        'buy_now_price': buyNowPrice,
        'starting_bid': startingBid,
        'expires_at': DateTime.now()
            .add(Duration(hours: durationHours))
            .toIso8601String(),
      });
      ref.read(userCardsProvider.notifier).refresh();
      await loadListings();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Place a bid via RPC (handles escrow, outbid refund)
  Future<Map<String, dynamic>> placeBid(String listingId, int bidAmount) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return {'success': false, 'error': 'Not logged in'};

      final result = await SupabaseService.client.rpc('place_market_bid', params: {
        'p_listing_id': listingId,
        'p_bidder_id': userId,
        'p_bid_amount': bidAmount,
      });

      // Refresh everything
      ref.read(currentUserProvider.notifier).silentRefresh();
      await loadListings();
      ref.read(myBidsProvider.notifier).load();

      if (result is Map) return Map<String, dynamic>.from(result);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Buy now via RPC (instant purchase)
  Future<Map<String, dynamic>> buyNow(String listingId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return {'success': false, 'error': 'Not logged in'};

      final result = await SupabaseService.client.rpc('execute_market_purchase', params: {
        'p_listing_id': listingId,
        'p_buyer_id': userId,
      });

      // Refresh user coins and cards
      ref.read(currentUserProvider.notifier).silentRefresh();
      await ref.read(userCardsProvider.notifier).refresh();
      await loadListings();
      ref.read(myBidsProvider.notifier).load();

      if (result is Map) return Map<String, dynamic>.from(result);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel own listing
  Future<Map<String, dynamic>> cancelListing(String listingId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return {'success': false, 'error': 'Not logged in'};

      final result = await SupabaseService.client.rpc('cancel_market_listing', params: {
        'p_listing_id': listingId,
        'p_seller_id': userId,
      });

      await ref.read(userCardsProvider.notifier).refresh();
      await loadListings();
      ref.read(myBidsProvider.notifier).load();
      ref.read(myListingsProvider.notifier).load();

      if (result is Map) return Map<String, dynamic>.from(result);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Settle an expired auction
  Future<void> _settleExpired(String listingId) async {
    try {
      await SupabaseService.client.rpc('settle_expired_auction', params: {
        'p_listing_id': listingId,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> refresh() => loadListings();
}

// ─── My active bids ───────────────────────────────────────────────
final myBidsProvider = StateNotifierProvider<MyBidsNotifier,
    AsyncValue<List<MarketBid>>>((ref) {
  return MyBidsNotifier();
});

class MyBidsNotifier extends StateNotifier<AsyncValue<List<MarketBid>>> {
  MyBidsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final rows = await SupabaseService.client
          .from('market_bids')
          .select('*, transfer_market(*, user_cards(*, player_cards(*)), users!seller_id(username))')
          .eq('bidder_id', userId)
          .order('created_at', ascending: false);

      final bids = (rows as List).map((r) => MarketBid.fromJson(r)).toList();
      state = AsyncValue.data(bids);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();
}

// ─── My active listings (seller view) ─────────────────────────────
final myListingsProvider = StateNotifierProvider<MyListingsNotifier,
    AsyncValue<List<MarketListing>>>((ref) {
  return MyListingsNotifier();
});

class MyListingsNotifier extends StateNotifier<AsyncValue<List<MarketListing>>> {
  MyListingsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final rows = await SupabaseService.client
          .from('transfer_market')
          .select('*, user_cards(*, player_cards(*)), users!seller_id(username)')
          .eq('seller_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final listings = (rows as List).map((r) => MarketListing.fromJson(r)).toList();
      state = AsyncValue.data(listings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();
}

// ─── Market filter ────────────────────────────────────────────────
final marketFilterProvider = StateProvider<MarketFilter>((ref) => const MarketFilter());

class MarketFilter {
  final String? rarity;
  final String? role;
  final String? country;
  final int? minPrice;
  final int? maxPrice;
  final String sortBy;

  const MarketFilter({
    this.rarity,
    this.role,
    this.country,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'newest',
  });
}
