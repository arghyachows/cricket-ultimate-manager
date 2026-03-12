import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'cards_provider.dart';

// Pack types
final packTypesProvider = FutureProvider<List<PackType>>((ref) async {
  final data = await SupabaseService.getPackTypes();
  return data.map((json) => PackType.fromJson(json)).toList();
});

// Pack opening state
final packOpeningProvider =
    StateNotifierProvider<PackOpeningNotifier, PackOpeningState>((ref) {
  return PackOpeningNotifier(ref);
});

class PackOpeningState {
  final bool isOpening;
  final List<UserCard> revealedCards;
  final int currentRevealIndex;
  final bool allRevealed;
  final String? error;

  const PackOpeningState({
    this.isOpening = false,
    this.revealedCards = const [],
    this.currentRevealIndex = -1,
    this.allRevealed = false,
    this.error,
  });

  PackOpeningState copyWith({
    bool? isOpening,
    List<UserCard>? revealedCards,
    int? currentRevealIndex,
    bool? allRevealed,
    String? error,
  }) {
    return PackOpeningState(
      isOpening: isOpening ?? this.isOpening,
      revealedCards: revealedCards ?? this.revealedCards,
      currentRevealIndex: currentRevealIndex ?? this.currentRevealIndex,
      allRevealed: allRevealed ?? this.allRevealed,
      error: error,
    );
  }
}

class PackOpeningNotifier extends StateNotifier<PackOpeningState> {
  final Ref ref;
  PackOpeningNotifier(this.ref) : super(const PackOpeningState());

  Future<bool> openPack(PackType packType) async {
    try {
      state = state.copyWith(isOpening: true, error: null);

      // Check user can afford
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = state.copyWith(isOpening: false, error: 'Not logged in');
        return false;
      }

      if (packType.isCoinPurchase && user.coins < packType.coinCost) {
        state = state.copyWith(isOpening: false, error: 'Not enough coins');
        return false;
      }

      if (packType.isPremiumPurchase &&
          user.premiumTokens < packType.premiumCost) {
        state = state.copyWith(isOpening: false, error: 'Not enough tokens');
        return false;
      }

      // Generate pack client-side using weighted random selection
      final rarities = <String>[];
      for (int i = 0; i < packType.cardCount; i++) {
        rarities.add(_pickRarity(packType));
      }

      // Fetch random player cards for each rarity
      final generatedCards = <UserCard>[];
      for (final rarity in rarities) {
        final result = await SupabaseService.client
            .from('player_cards')
            .select()
            .eq('rarity', rarity)
            .eq('is_available', true);

        final cards = result as List;
        if (cards.isEmpty) continue;

        final randomCard = cards[Random().nextInt(cards.length)];

        // Insert into user_cards
        final inserted = await SupabaseService.client
            .from('user_cards')
            .insert({
              'user_id': user.id,
              'card_id': randomCard['id'],
              'is_tradeable': true,
            })
            .select('*, player_cards:card_id(*)')
            .single();

        generatedCards.add(UserCard.fromJson(inserted));
      }

      if (generatedCards.isEmpty) {
        state = state.copyWith(isOpening: false, error: 'No cards generated');
        return false;
      }

      // Deduct cost from user
      if (packType.isCoinPurchase) {
        await SupabaseService.client
            .from('users')
            .update({'coins': user.coins - packType.coinCost})
            .eq('id', user.id);
      } else if (packType.isPremiumPurchase) {
        await SupabaseService.client
            .from('users')
            .update({'premium_tokens': user.premiumTokens - packType.premiumCost})
            .eq('id', user.id);
      }

      // Record pack opening
      await SupabaseService.client.from('pack_openings').insert({
        'user_id': user.id,
        'pack_type_id': packType.id,
        'cards_received': generatedCards.map((c) => c.id).toList(),
      });

      state = state.copyWith(
        isOpening: false,
        revealedCards: generatedCards,
        currentRevealIndex: -1,
        allRevealed: false,
      );

      // Refresh user data from server
      ref.read(currentUserProvider.notifier).refresh();
      ref.read(userCardsProvider.notifier).addCards(generatedCards);

      return true;
    } catch (e) {
      state = state.copyWith(isOpening: false, error: e.toString());
      return false;
    }
  }

  void revealNext() {
    if (state.currentRevealIndex >= state.revealedCards.length - 1) {
      state = state.copyWith(allRevealed: true);
      return;
    }
    state = state.copyWith(
      currentRevealIndex: state.currentRevealIndex + 1,
    );
  }

  void revealAll() {
    state = state.copyWith(
      currentRevealIndex: state.revealedCards.length - 1,
      allRevealed: true,
    );
  }

  void reset() {
    state = const PackOpeningState();
  }

  static String _pickRarity(PackType pack) {
    final rand = Random().nextDouble() * 100;
    double cumulative = 0;

    cumulative += pack.legendChance;
    if (rand < cumulative) return 'legend';

    cumulative += pack.eliteChance;
    if (rand < cumulative) return 'elite';

    cumulative += pack.goldChance;
    if (rand < cumulative) return 'gold';

    cumulative += pack.silverChance;
    if (rand < cumulative) return 'silver';

    return 'bronze';
  }
}
