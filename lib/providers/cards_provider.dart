import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';

// All user cards
final userCardsProvider =
    StateNotifierProvider<UserCardsNotifier, AsyncValue<List<UserCard>>>((ref) {
  return UserCardsNotifier();
});

class UserCardsNotifier extends StateNotifier<AsyncValue<List<UserCard>>> {
  UserCardsNotifier() : super(const AsyncValue.loading()) {
    loadCards();
  }

  Future<void> loadCards() async {
    try {
      state = const AsyncValue.loading();
      final data = await SupabaseService.getUserCards();
      final cards = data.map((json) => UserCard.fromJson(json)).toList();
      state = AsyncValue.data(cards);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addCards(List<UserCard> newCards) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, ...newCards]);
  }

  void removeCard(String cardId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((c) => c.id != cardId).toList());
  }

  Future<void> refresh() => loadCards();
}

// Filter state for collection
final cardFilterProvider = StateProvider<CardFilter>((ref) => const CardFilter());

class CardFilter {
  final String? rarity;
  final String? role;
  final String? sortBy;
  final bool ascending;

  const CardFilter({this.rarity, this.role, this.sortBy, this.ascending = false});

  CardFilter copyWith({
    String? rarity,
    String? role,
    String? sortBy,
    bool? ascending,
  }) {
    return CardFilter(
      rarity: rarity,
      role: role,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

// Filtered cards
final filteredUserCardsProvider = Provider<List<UserCard>>((ref) {
  final cards = ref.watch(userCardsProvider).valueOrNull ?? [];
  final filter = ref.watch(cardFilterProvider);

  var filtered = cards.where((c) {
    if (filter.rarity != null && c.playerCard?.rarity != filter.rarity) {
      return false;
    }
    if (filter.role != null && c.playerCard?.role != filter.role) {
      return false;
    }
    return true;
  }).toList();

  if (filter.sortBy != null) {
    filtered.sort((a, b) {
      int compare;
      switch (filter.sortBy) {
        case 'rating':
          compare = (a.playerCard?.rating ?? 0).compareTo(b.playerCard?.rating ?? 0);
          break;
        case 'batting':
          compare = (a.playerCard?.batting ?? 0).compareTo(b.playerCard?.batting ?? 0);
          break;
        case 'bowling':
          compare = (a.playerCard?.bowling ?? 0).compareTo(b.playerCard?.bowling ?? 0);
          break;
        case 'name':
          compare = (a.playerCard?.playerName ?? '').compareTo(b.playerCard?.playerName ?? '');
          break;
        default:
          compare = 0;
      }
      return filter.ascending ? compare : -compare;
    });
  }

  return filtered;
});
