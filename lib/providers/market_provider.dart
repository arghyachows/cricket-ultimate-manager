import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';

// Market listings
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
      state = const AsyncValue.loading();
      final data = await SupabaseService.getMarketListings();
      final listings =
          data.map((json) => MarketListing.fromJson(json)).toList();
      state = AsyncValue.data(listings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeToUpdates() {
    _channel = SupabaseService.subscribeToMarket((update) {
      loadListings(); // Refresh on any market change
    });
  }

  Future<bool> listCard({
    required String userCardId,
    required int buyNowPrice,
    required int startingBid,
    int durationHours = 24,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.client.from('transfer_market').insert({
        'seller_id': userId,
        'user_card_id': userCardId,
        'buy_now_price': buyNowPrice,
        'starting_bid': startingBid,
        'expires_at': DateTime.now()
            .add(Duration(hours: durationHours))
            .toIso8601String(),
      });
      await loadListings();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> placeBid(String listingId, int bidAmount) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      await SupabaseService.client.from('transfer_market').update({
        'current_bid': bidAmount,
        'current_bidder_id': userId,
      }).eq('id', listingId);

      await loadListings();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> buyNow(String listingId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return false;

      final listing = state.valueOrNull?.firstWhere((l) => l.id == listingId);
      if (listing == null) return false;

      // Check user has enough coins
      final userData = await SupabaseService.getCurrentUser();
      if (userData == null) return false;
      final user = UserModel.fromJson(userData);
      if (user.coins < listing.buyNowPrice) return false;

      // Execute purchase via RPC or direct updates
      await SupabaseService.client.rpc('execute_market_purchase', params: {
        'p_listing_id': listingId,
        'p_buyer_id': userId,
      });

      ref.read(currentUserProvider.notifier).refresh();
      await loadListings();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> refresh() => loadListings();
}

// Market filter
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
