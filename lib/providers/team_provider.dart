import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';

// Active team
final teamProvider =
    StateNotifierProvider<TeamNotifier, AsyncValue<Team?>>((ref) {
  return TeamNotifier();
});

class TeamNotifier extends StateNotifier<AsyncValue<Team?>> {
  RealtimeChannel? _squadChannel;
  RealtimeChannel? _lineupChannel;

  TeamNotifier() : super(const AsyncValue.loading()) {
    loadTeam();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    _squadChannel = SupabaseService.subscribeToSquad(userId, () {
      loadTeam();
    });
    // Also listen to lineup_players changes
    _lineupChannel = SupabaseService.client
        .channel('lineup_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lineup_players',
          callback: (_) => loadTeam(),
        )
        .subscribe();
  }

  Future<void> loadTeam() async {
    try {
      // Only show loading spinner on very first load
      if (!state.hasValue) {
        state = const AsyncValue.loading();
      }
      final data = await SupabaseService.getActiveTeam();
      if (data != null) {
        state = AsyncValue.data(Team.fromJson(data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<Team?> createTeam(String name) async {
    try {
      await SupabaseService.createTeam(name);
      await loadTeam();
      return state.valueOrNull;
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // SQUAD (Roster) operations
  // ──────────────────────────────────────────────

  Future<void> addPlayerToSquad(String squadId, String userCardId, int position) async {
    // Remove any existing player at this position
    await SupabaseService.client
        .from('squad_players')
        .delete()
        .eq('squad_id', squadId)
        .eq('position', position);

    // Remove this card if it's already in another position
    await SupabaseService.client
        .from('squad_players')
        .delete()
        .eq('squad_id', squadId)
        .eq('user_card_id', userCardId);

    await SupabaseService.client.from('squad_players').insert({
      'squad_id': squadId,
      'user_card_id': userCardId,
      'position': position,
    });

    await loadTeam();
  }

  Future<void> removePlayerFromSquad(String squadPlayerId) async {
    // Also remove from lineup if present
    final player = await SupabaseService.client
        .from('squad_players')
        .select('squad_id, user_card_id')
        .eq('id', squadPlayerId)
        .maybeSingle();

    if (player != null) {
      await SupabaseService.client
          .from('lineup_players')
          .delete()
          .eq('squad_id', player['squad_id'])
          .eq('user_card_id', player['user_card_id']);
    }

    await SupabaseService.client
        .from('squad_players')
        .delete()
        .eq('id', squadPlayerId);

    await loadTeam();
  }

  // ──────────────────────────────────────────────
  // LINEUP (Playing XI) operations
  // ──────────────────────────────────────────────

  /// Add a card to the lineup at the next available batting order slot.
  Future<void> addToLineup(String squadId, String userCardId) async {
    final squad = state.valueOrNull?.activeSquad;
    if (squad == null) return;
    if (squad.lineup.length >= 11) return;

    // Find next available batting order (1-11)
    final usedOrders = squad.lineup.map((l) => l.battingOrder).toSet();
    int order = 1;
    for (int i = 1; i <= 11; i++) {
      if (!usedOrders.contains(i)) { order = i; break; }
    }

    // Also ensure the card is in the squad roster
    final inSquad = squad.players.any((p) => p.userCardId == userCardId);
    if (!inSquad) {
      // Auto-add to squad at next available position
      final usedPositions = squad.players.map((p) => p.position).toSet();
      int pos = 1;
      for (int i = 1; i <= 30; i++) {
        if (!usedPositions.contains(i)) { pos = i; break; }
      }
      await SupabaseService.client.from('squad_players').insert({
        'squad_id': squadId,
        'user_card_id': userCardId,
        'position': pos,
      });
    }

    await SupabaseService.client.from('lineup_players').insert({
      'squad_id': squadId,
      'user_card_id': userCardId,
      'batting_order': order,
    });

    await loadTeam();
  }

  /// Remove a card from the lineup (keeps in squad).
  Future<void> removeFromLineup(String lineupPlayerId) async {
    final squad = state.valueOrNull?.activeSquad;
    if (squad == null) return;

    await SupabaseService.client
        .from('lineup_players')
        .delete()
        .eq('id', lineupPlayerId);

    // Normalize batting orders to be contiguous
    await _normalizeLineupOrder(squad.id);
    await loadTeam();
  }

  /// Swap a lineup player with a new card from the collection.
  Future<void> swapLineupPlayer(String lineupPlayerId, String newUserCardId) async {
    // Get the current lineup entry
    final oldRow = await SupabaseService.client
        .from('lineup_players')
        .select('squad_id, batting_order, is_captain, is_vice_captain')
        .eq('id', lineupPlayerId)
        .maybeSingle();
    if (oldRow == null) return;

    final squadId = oldRow['squad_id'] as String;
    final battingOrder = oldRow['batting_order'] as int;
    final wasCaptain = oldRow['is_captain'] as bool? ?? false;
    final wasVC = oldRow['is_vice_captain'] as bool? ?? false;

    // Delete old lineup entry
    await SupabaseService.client
        .from('lineup_players')
        .delete()
        .eq('id', lineupPlayerId);

    // Ensure new card is in the squad roster
    final squad = state.valueOrNull?.activeSquad;
    if (squad != null) {
      final inSquad = squad.players.any((p) => p.userCardId == newUserCardId);
      if (!inSquad) {
        final usedPositions = squad.players.map((p) => p.position).toSet();
        int pos = 1;
        for (int i = 1; i <= 30; i++) {
          if (!usedPositions.contains(i)) { pos = i; break; }
        }
        await SupabaseService.client.from('squad_players').insert({
          'squad_id': squadId,
          'user_card_id': newUserCardId,
          'position': pos,
        });
      }
    }

    // Insert new lineup entry at the same batting order
    await SupabaseService.client.from('lineup_players').insert({
      'squad_id': squadId,
      'user_card_id': newUserCardId,
      'batting_order': battingOrder,
      'is_captain': wasCaptain,
      'is_vice_captain': wasVC,
    });

    await loadTeam();
  }

  Future<void> setCaptain(String lineupPlayerId) async {
    final squad = state.valueOrNull?.activeSquad;
    if (squad == null) return;

    // Clear existing captain
    for (final lp in squad.lineup.where((p) => p.isCaptain)) {
      await SupabaseService.client
          .from('lineup_players')
          .update({'is_captain': false}).eq('id', lp.id);
    }

    // Set new captain
    await SupabaseService.client
        .from('lineup_players')
        .update({'is_captain': true}).eq('id', lineupPlayerId);
    await loadTeam();
  }

  Future<void> setViceCaptain(String lineupPlayerId) async {
    final squad = state.valueOrNull?.activeSquad;
    if (squad == null) return;

    // Clear existing vice captain
    for (final lp in squad.lineup.where((p) => p.isViceCaptain)) {
      await SupabaseService.client
          .from('lineup_players')
          .update({'is_vice_captain': false}).eq('id', lp.id);
    }

    // Set new vice captain
    await SupabaseService.client
        .from('lineup_players')
        .update({'is_vice_captain': true}).eq('id', lineupPlayerId);
    await loadTeam();
  }

  /// Reorder the lineup: move item at [oldIndex] to [newIndex] (0-based).
  Future<void> reorderLineup(List<LineupPlayer> currentOrder, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final reordered = List<LineupPlayer>.from(currentOrder);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Optimistically update local state
    final team = state.valueOrNull;
    if (team != null) {
      final squad = team.activeSquad;
      if (squad != null) {
        final updatedLineup = <LineupPlayer>[];
        for (int i = 0; i < reordered.length; i++) {
          final lp = reordered[i];
          updatedLineup.add(LineupPlayer(
            id: lp.id,
            squadId: lp.squadId,
            userCardId: lp.userCardId,
            battingOrder: i + 1,
            isCaptain: lp.isCaptain,
            isViceCaptain: lp.isViceCaptain,
            userCard: lp.userCard,
          ));
        }
        final updatedSquads = team.squads.map((s) {
          if (s.id == squad.id) {
            return Squad(
              id: s.id,
              teamId: s.teamId,
              squadName: s.squadName,
              formation: s.formation,
              isActive: s.isActive,
              players: s.players,
              lineup: updatedLineup,
            );
          }
          return s;
        }).toList();
        state = AsyncValue.data(Team(
          id: team.id,
          userId: team.userId,
          teamName: team.teamName,
          logoUrl: team.logoUrl,
          chemistry: team.chemistry,
          overallRating: team.overallRating,
          isActive: team.isActive,
          squads: updatedSquads,
        ));
      }
    }

    // Persist new batting order to DB
    for (int i = 0; i < reordered.length; i++) {
      await SupabaseService.client
          .from('lineup_players')
          .update({'batting_order': i + 1}).eq('id', reordered[i].id);
    }

    await loadTeam();
  }

  /// Re-number batting_order 1..N contiguously.
  Future<void> _normalizeLineupOrder(String squadId) async {
    final rows = await SupabaseService.client
        .from('lineup_players')
        .select('id, batting_order')
        .eq('squad_id', squadId)
        .order('batting_order');

    final players = List<Map<String, dynamic>>.from(rows);
    for (int i = 0; i < players.length; i++) {
      if (players[i]['batting_order'] != i + 1) {
        await SupabaseService.client
            .from('lineup_players')
            .update({'batting_order': i + 1}).eq('id', players[i]['id']);
      }
    }
  }

  // ──────────────────────────────────────────────
  // AUTO-PICK LINEUP
  // ──────────────────────────────────────────────

  Future<void> autoPickLineup(List<UserCard> allCards) async {
    final team = state.valueOrNull;
    if (team == null) return;
    final squad = team.activeSquad;
    if (squad == null) return;

    // Sort entire collection by rating descending
    final candidates = allCards
        .where((c) => c.playerCard != null)
        .toList()
      ..sort((a, b) => (b.playerCard!.rating).compareTo(a.playerCard!.rating));

    if (candidates.isEmpty) return;

    int ratingOf(UserCard c) => c.playerCard?.rating ?? 0;
    int battingOf(UserCard c) => c.playerCard?.batting ?? 0;
    String roleOf(UserCard c) => c.playerCard?.role ?? 'batsman';

    // Always pick the best 11 from scratch (ignore existing lineup)
    final selected = <UserCard>[];
    final selectedIds = <String>{};
    final selectedCardIds = <String>{};

    void pick(String role, int count) {
      int picked = 0;
      for (final card in candidates) {
        if (picked >= count) break;
        if (selected.length >= 11) break;
        if (selectedIds.contains(card.id)) continue;
        if (selectedCardIds.contains(card.cardId)) continue;
        if (roleOf(card) == role) {
          selected.add(card);
          selectedIds.add(card.id);
          selectedCardIds.add(card.cardId);
          picked++;
        }
      }
    }

    // Target composition: 4 bat, 1 WK, 2 AR, 4 bowl
    pick('batsman', 4);
    pick('wicket_keeper', 1);
    pick('all_rounder', 2);
    pick('bowler', 4);

    // Fill remaining by overall rating (unique players)
    for (final card in candidates) {
      if (selected.length >= 11) break;
      if (!selectedIds.contains(card.id) && !selectedCardIds.contains(card.cardId)) {
        selected.add(card);
        selectedIds.add(card.id);
        selectedCardIds.add(card.cardId);
      }
    }

    // Last resort: allow duplicate underlying players
    if (selected.length < 11) {
      for (final card in candidates) {
        if (selected.length >= 11) break;
        if (!selectedIds.contains(card.id)) {
          selected.add(card);
          selectedIds.add(card.id);
        }
      }
    }

    if (selected.isEmpty) return;

    // Ensure all selected cards are in the squad roster
    final existingUserCardIds = squad.players.map((sp) => sp.userCardId).toSet();
    final usedPositions = squad.players.map((sp) => sp.position).toSet();

    for (final card in selected) {
      if (!existingUserCardIds.contains(card.id)) {
        int pos = 1;
        for (int i = 1; i <= 30; i++) {
          if (!usedPositions.contains(i)) { pos = i; break; }
        }
        usedPositions.add(pos);
        await SupabaseService.client.from('squad_players').insert({
          'squad_id': squad.id,
          'user_card_id': card.id,
          'position': pos,
        });
        existingUserCardIds.add(card.id);
      }
    }

    // Sort selected by batting order score for the full lineup
    int battingOrderScore(UserCard c) {
      final role = roleOf(c);
      final bonus = role == 'batsman'
          ? 40
          : role == 'wicket_keeper'
              ? 30
              : role == 'all_rounder'
                  ? 20
                  : 0;
      return battingOf(c) * 2 + ratingOf(c) + bonus;
    }

    final ordered = List<UserCard>.from(selected)
      ..sort((a, b) => battingOrderScore(b).compareTo(battingOrderScore(a)));

    // Captain = highest rated, VC = second highest
    String? captainCardId;
    String? vcCardId;
    final leadership = List<UserCard>.from(selected)
      ..sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
    for (final c in leadership) {
      if (captainCardId == null) {
        captainCardId = c.id;
      } else if (vcCardId == null && c.id != captainCardId) {
        vcCardId = c.id;
        break;
      }
    }

    // Pause realtime to avoid state churn during multi-step write
    _lineupChannel?.unsubscribe();

    try {
      // Clear existing lineup and insert fresh
      await SupabaseService.client
          .from('lineup_players')
          .delete()
          .eq('squad_id', squad.id);

      // Batch insert all lineup players at once
      final rows = <Map<String, dynamic>>[];
      for (int i = 0; i < ordered.length; i++) {
        rows.add({
          'squad_id': squad.id,
          'user_card_id': ordered[i].id,
          'batting_order': i + 1,
          'is_captain': ordered[i].id == captainCardId,
          'is_vice_captain': ordered[i].id == vcCardId,
        });
      }
      if (rows.isNotEmpty) {
        await SupabaseService.client.from('lineup_players').insert(rows);
      }
    } finally {
      // Re-subscribe to realtime
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        _lineupChannel = SupabaseService.client
            .channel('lineup_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'lineup_players',
              callback: (_) => loadTeam(),
            )
            .subscribe();
      }
    }

    await loadTeam();
  }

  Future<void> refresh() => loadTeam();

  @override
  void dispose() {
    _squadChannel?.unsubscribe();
    _lineupChannel?.unsubscribe();
    super.dispose();
  }
}

// Chemistry calculation — uses lineup (LineupPlayer)
final chemistryProvider = Provider<int>((ref) {
  final team = ref.watch(teamProvider).valueOrNull;
  if (team == null) return 0;
  final squad = team.activeSquad;
  if (squad == null) return 0;
  return _calculateChemistry(squad.playingXI);
});

int _calculateChemistry(List<LineupPlayer> playingXI) {
  int chemistry = 0;

  // Country links
  final countryGroups = <String, int>{};
  for (final p in playingXI) {
    final country = p.userCard?.playerCard?.country;
    if (country != null) {
      countryGroups[country] = (countryGroups[country] ?? 0) + 1;
    }
  }
  for (final count in countryGroups.values) {
    if (count > 1) {
      chemistry += (count * (count - 1) ~/ 2) * 3;
    }
  }

  // Team links
  final teamGroups = <String, int>{};
  for (final p in playingXI) {
    final team = p.userCard?.playerCard?.team;
    if (team != null) {
      teamGroups[team] = (teamGroups[team] ?? 0) + 1;
    }
  }
  for (final count in teamGroups.values) {
    if (count > 1) {
      chemistry += (count * (count - 1) ~/ 2) * 5;
    }
  }

  // League links
  final leagueGroups = <String, int>{};
  for (final p in playingXI) {
    final league = p.userCard?.playerCard?.league;
    if (league != null) {
      leagueGroups[league] = (leagueGroups[league] ?? 0) + 1;
    }
  }
  for (final count in leagueGroups.values) {
    if (count > 1) {
      chemistry += (count * (count - 1) ~/ 2) * 2;
    }
  }

  // Role balance
  final roles = playingXI
      .map((p) => p.userCard?.playerCard?.role)
      .where((r) => r != null)
      .toSet();
  if (roles.length == 4) chemistry += 10;

  return chemistry.clamp(0, 100);
}
