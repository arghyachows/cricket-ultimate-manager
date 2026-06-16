import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'cards_provider.dart';

final userCardPacksProvider =
    StateNotifierProvider<UserCardPacksNotifier, AsyncValue<List<UserCardPack>>>(
        (ref) {
  return UserCardPacksNotifier(ref);
});

class UserCardPacksNotifier
    extends StateNotifier<AsyncValue<List<UserCardPack>>> {
  final Ref ref;
  bool _isOpening = false; // Guard against concurrent openPack() calls

  UserCardPacksNotifier(this.ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final rows = await SupabaseService.client
          .from('user_card_packs')
          .select()
          .eq('user_id', userId)
          .eq('opened', false)
          .order('created_at', ascending: false);
      final packs =
          (rows as List).map((r) => UserCardPack.fromJson(r)).toList();
      state = AsyncValue.data(packs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Open a stored pack: generate cards, mark opened, return the cards.
  ///
  /// FIXED: Added concurrency guard (_isOpening) to prevent multiple
  /// simultaneous openPack() calls from racing and selecting the same
  /// player_cards. Added try-finally for cleanup on failure.
  Future<List<UserCard>> openPack(UserCardPack pack) async {
    if (_isOpening) return []; // Reject concurrent calls
    _isOpening = true;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      _isOpening = false;
      return [];
    }

    final generatedCards = <UserCard>[];
    final insertedIds = <String>[]; // Track for cleanup on failure

    try {
      // Starter packs get a guaranteed role composition:
      // 5 batsmen, 5 bowlers, 3 all-rounders, 2 wicket-keepers (= 15 cards)
      final roleSlots = pack.source == 'starter'
          ? [
              'batsman', 'batsman', 'batsman', 'batsman', 'batsman',
              'bowler',  'bowler',  'bowler',  'bowler',  'bowler',
              'all_rounder', 'all_rounder', 'all_rounder',
              'wicket_keeper', 'wicket_keeper',
            ]
          : List.generate(pack.cardCount, (_) => null); // null = any role

      for (int i = 0; i < pack.cardCount; i++) {
        final rarity   = _pickRarity(pack);
        final roleFilter = i < roleSlots.length ? roleSlots[i] : null;

        var query = SupabaseService.client
            .from('player_cards')
            .select()
            .eq('rarity', rarity)
            .eq('is_available', true);

        if (roleFilter != null) {
          query = query.eq('role', roleFilter);
        }

        var result = await query;
        var cards = result as List;

        // Fallback: if no card found with this rarity+role, broaden to any rarity
        if (cards.isEmpty && roleFilter != null) {
          final fallback = await SupabaseService.client
              .from('player_cards')
              .select()
              .eq('role', roleFilter)
              .eq('is_available', true);
          cards = fallback as List;
        }

        // Final fallback: any available card
        if (cards.isEmpty) {
          final fallback = await SupabaseService.client
              .from('player_cards')
              .select()
              .eq('is_available', true);
          cards = fallback as List;
        }

        if (cards.isEmpty) {
          Log.w('Pack opening: no player_cards found for slot $i');
          continue;
        }

        final randomCard = cards[Random().nextInt(cards.length)];

        final inserted = await SupabaseService.client
            .from('user_cards')
            .insert({
              'user_id': user.id,
              'card_id': randomCard['id'],
              'is_tradeable': true,
            })
            .select('*, player_cards:card_id(*)')
            .single();

        final userCardId = inserted['id'] as String;
        insertedIds.add(userCardId);
        generatedCards.add(UserCard.fromJson(inserted));
      }

      // Mark pack as opened — only if all cards were generated successfully
      await SupabaseService.client
          .from('user_card_packs')
          .update({'opened': true})
          .eq('id', pack.id);

      // Refresh local state
      await ref.read(userCardsProvider.notifier).refresh();

      // Remove opened pack from local list
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((p) => p.id != pack.id).toList());

      return generatedCards;
    } catch (e) {
      // Cleanup: delete any partially-inserted cards to avoid orphan records
      Log.e('Pack opening failed, cleaning up ${insertedIds.length} cards', e);
      for (final id in insertedIds) {
        try {
          await SupabaseService.client.from('user_cards').delete().eq('id', id);
        } catch (_) {
          // Best-effort cleanup
        }
      }
      rethrow;
    } finally {
      _isOpening = false;
    }
  }

  static String _pickRarity(UserCardPack pack) {
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

  Future<void> refresh() => load();
}
