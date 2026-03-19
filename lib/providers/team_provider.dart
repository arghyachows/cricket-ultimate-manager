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
  RealtimeChannel? _channel;

  TeamNotifier() : super(const AsyncValue.loading()) {
    loadTeam();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    _channel = SupabaseService.subscribeToSquad(userId, () {
      loadTeam();
    });
  }

  Future<void> _normalizePlayingXIBattingOrder(String squadId) async {
    final rows = await SupabaseService.client
        .from('squad_players')
        .select('id, position, batting_order')
        .eq('squad_id', squadId)
        .eq('is_playing_xi', true);

    final players = List<Map<String, dynamic>>.from(rows);
    players.sort((a, b) {
      final ao = a['batting_order'] as int?;
      final bo = b['batting_order'] as int?;
      if (ao != null && bo != null) return ao.compareTo(bo);
      if (ao != null) return -1;
      if (bo != null) return 1;
      final ap = (a['position'] as int?) ?? 999;
      final bp = (b['position'] as int?) ?? 999;
      return ap.compareTo(bp);
    });

    for (int i = 0; i < players.length; i++) {
      await SupabaseService.client
          .from('squad_players')
          .update({'batting_order': i + 1}).eq('id', players[i]['id']);
    }
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
      // Reload to get full team with squads joined
      await loadTeam();
      return state.valueOrNull;
    } catch (e) {
      return null;
    }
  }

  Future<void> addPlayerToSquad(String squadId, String userCardId, int position,
      {bool isPlayingXI = false}) async {
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
      'is_playing_xi': isPlayingXI,
      'batting_order': isPlayingXI ? position : null,
    });

    await _normalizePlayingXIBattingOrder(squadId);
    await loadTeam();
  }

  /// Swap a player in the Playing XI with a new card from the collection.
  /// Keeps the same position & batting order slot; the old card stays in squad but leaves XI.
  Future<void> swapPlayingXIPlayer(String oldSquadPlayerId, String newUserCardId) async {
    // Fetch old player's slot info
    final oldRow = await SupabaseService.client
        .from('squad_players')
        .select('squad_id, position, batting_order, is_captain, is_vice_captain')
        .eq('id', oldSquadPlayerId)
        .maybeSingle();
    if (oldRow == null) return;

    final squadId = oldRow['squad_id'] as String;
    final battingOrder = oldRow['batting_order'] as int?;
    final wasCaptain = oldRow['is_captain'] as bool? ?? false;
    final wasVC = oldRow['is_vice_captain'] as bool? ?? false;

    // Remove old player from XI (keep in squad)
    await SupabaseService.client
        .from('squad_players')
        .update({
          'is_playing_xi': false,
          'batting_order': null,
          'is_captain': false,
          'is_vice_captain': false,
        })
        .eq('id', oldSquadPlayerId);

    // Check if new card is already in the squad
    final existingRow = await SupabaseService.client
        .from('squad_players')
        .select('id')
        .eq('squad_id', squadId)
        .eq('user_card_id', newUserCardId)
        .maybeSingle();

    if (existingRow != null) {
      // Card already in squad — promote it to XI at the same batting position
      await SupabaseService.client
          .from('squad_players')
          .update({
            'is_playing_xi': true,
            'batting_order': battingOrder,
            'is_captain': wasCaptain,
            'is_vice_captain': wasVC,
          })
          .eq('id', existingRow['id']);
    } else {
      // Card not in squad — insert it directly into XI
      // First find an available squad position for the new card
      final allRows = await SupabaseService.client
          .from('squad_players')
          .select('position')
          .eq('squad_id', squadId);
      final usedPositions = (allRows as List).map((r) => r['position'] as int).toSet();
      int newPos = 1;
      for (int i = 1; i <= 30; i++) {
        if (!usedPositions.contains(i)) { newPos = i; break; }
      }

      await SupabaseService.client.from('squad_players').insert({
        'squad_id': squadId,
        'user_card_id': newUserCardId,
        'position': newPos,
        'is_playing_xi': true,
        'batting_order': battingOrder,
        'is_captain': wasCaptain,
        'is_vice_captain': wasVC,
      });
    }

    await _normalizePlayingXIBattingOrder(squadId);
    await loadTeam();
  }

  Future<void> removePlayerFromSquad(String squadPlayerId) async {
    final player = await SupabaseService.client
        .from('squad_players')
        .select('squad_id, is_playing_xi')
        .eq('id', squadPlayerId)
        .maybeSingle();

    await SupabaseService.client
        .from('squad_players')
        .delete()
        .eq('id', squadPlayerId);

    final squadId = player?['squad_id'] as String?;
    final wasXI = player?['is_playing_xi'] as bool? ?? false;
    if (squadId != null && wasXI) {
      await _normalizePlayingXIBattingOrder(squadId);
    }
    await loadTeam();
  }

  Future<void> setPlayingXI(String squadPlayerId, bool isXI) async {
    final player = await SupabaseService.client
        .from('squad_players')
        .select('squad_id, position')
        .eq('id', squadPlayerId)
        .maybeSingle();
    final squadId = player?['squad_id'] as String?;
    final position = player?['position'] as int?;

    await SupabaseService.client
        .from('squad_players')
        .update({
          'is_playing_xi': isXI,
          'batting_order': isXI ? position : null,
        }).eq('id', squadPlayerId);

    if (squadId != null) {
      await _normalizePlayingXIBattingOrder(squadId);
    }
    await loadTeam();
  }

  Future<void> setCaptain(String squadPlayerId) async {
    final team = state.valueOrNull;
    if (team == null) return;
    final squad = team.activeSquad;
    if (squad == null) return;

    // Clear existing captain
    for (final player in squad.players.where((p) => p.isCaptain)) {
      await SupabaseService.client
          .from('squad_players')
          .update({'is_captain': false}).eq('id', player.id);
    }

    // Set new captain
    await SupabaseService.client
        .from('squad_players')
        .update({'is_captain': true}).eq('id', squadPlayerId);
    await loadTeam();
  }

  Future<void> setViceCaptain(String squadPlayerId) async {
    final team = state.valueOrNull;
    if (team == null) return;
    final squad = team.activeSquad;
    if (squad == null) return;

    // Clear existing vice captain
    for (final player in squad.players.where((p) => p.isViceCaptain)) {
      await SupabaseService.client
          .from('squad_players')
          .update({'is_vice_captain': false}).eq('id', player.id);
    }

    // Set new vice captain
    await SupabaseService.client
        .from('squad_players')
        .update({'is_vice_captain': true}).eq('id', squadPlayerId);
    await loadTeam();
  }

  Future<void> setBattingOrder(String squadPlayerId, int order) async {
    await SupabaseService.client
        .from('squad_players')
        .update({'batting_order': order}).eq('id', squadPlayerId);
    await loadTeam();
  }

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

    // Pick best per role: 4 bat, 1 WK, 2 AR, 4 bowl
    final selected = <UserCard>[];
    final selectedIds = <String>{};      // user_card UUIDs
    final selectedCardIds = <String>{};  // underlying player_card UUIDs (prevent same player twice)

    void pick(String role, int count) {
      int picked = 0;
      for (final card in candidates) {
        if (picked >= count) break;
        if (selectedIds.contains(card.id)) continue;
        if (selectedCardIds.contains(card.cardId)) continue; // skip duplicate player
        if (roleOf(card) == role) {
          selected.add(card);
          selectedIds.add(card.id);
          selectedCardIds.add(card.cardId);
          picked++;
        }
      }
    }

    pick('batsman', 4);
    pick('wicket_keeper', 1);
    pick('all_rounder', 2);
    pick('bowler', 4);

    // Fill any remaining slots by overall rating
    for (final card in candidates) {
      if (selected.length >= 11) break;
      if (!selectedIds.contains(card.id) && !selectedCardIds.contains(card.cardId)) {
        selected.add(card);
        selectedIds.add(card.id);
        selectedCardIds.add(card.cardId);
      }
    }

    if (selected.isEmpty) return;

    // Add any selected cards not yet in the squad
    final existingUserCardIds = squad.players.map((sp) => sp.userCardId).toSet();
    final usedPositions = squad.players.map((sp) => sp.position).toSet();

    int nextAvailablePosition() {
      for (int i = 1; i <= 30; i++) {
        if (!usedPositions.contains(i)) {
          usedPositions.add(i);
          return i;
        }
      }
      return -1;
    }

    bool squadChanged = false;
    for (final card in selected) {
      if (!existingUserCardIds.contains(card.id)) {
        final pos = nextAvailablePosition();
        if (pos == -1) continue; // squad is full (30 players)
        await SupabaseService.client.from('squad_players').insert({
          'squad_id': squad.id,
          'user_card_id': card.id,
          'position': pos,
          'is_playing_xi': false,
        });
        existingUserCardIds.add(card.id);
        squadChanged = true;
      }
    }

    // Reload if new players were inserted so we have their squad_player IDs
    if (squadChanged) await loadTeam();

    final refreshedSquad = state.valueOrNull?.activeSquad ?? squad;
    final spByUserCardId = <String, SquadPlayer>{
      for (final sp in refreshedSquad.players) sp.userCardId: sp,
    };

    // Batting order: batsmen first, then WK, all-rounders, bowlers; within each by batting
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

    final battingOrder = List<UserCard>.from(selected)
      ..sort((a, b) => battingOrderScore(b).compareTo(battingOrderScore(a)));

    final battingOrderBySPId = <String, int>{};
    for (int i = 0; i < battingOrder.length; i++) {
      final sp = spByUserCardId[battingOrder[i].id];
      if (sp != null) battingOrderBySPId[sp.id] = i + 1;
    }

    // Captain = highest rated, VC = second highest
    final leadership = List<UserCard>.from(selected)
      ..sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
    final captainSPId = spByUserCardId[leadership.first.id]?.id;
    final vcSPId = leadership.length > 1 ? spByUserCardId[leadership[1].id]?.id : null;

    // Update all squad_players: set XI status, batting order, captain/VC
    for (final sp in refreshedSquad.players) {
      final isXI = selectedIds.contains(sp.userCardId);
      await SupabaseService.client
          .from('squad_players')
          .update({
            'is_playing_xi': isXI,
            'batting_order': isXI ? battingOrderBySPId[sp.id] : null,
            'is_captain': sp.id == captainSPId,
            'is_vice_captain': vcSPId != null && sp.id == vcSPId,
          })
          .eq('id', sp.id);
    }

    await _normalizePlayingXIBattingOrder(refreshedSquad.id);
    await loadTeam();
  }

  /// Reorder Playing XI: move the player at [oldIndex] to [newIndex] (0-based)
  /// Reorders the playing XI and persists the new batting_order values.
  /// Uses batting_order (no UNIQUE constraint) to avoid DB conflict issues.
  Future<void> reorderPlayingXI(List<SquadPlayer> currentOrder, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final reordered = List<SquadPlayer>.from(currentOrder);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Build new batting order map (1-based)
    final battingOrderUpdates = <String, int>{};
    for (int i = 0; i < reordered.length; i++) {
      battingOrderUpdates[reordered[i].id] = i + 1;
    }

    // Optimistically update local state so the UI doesn't snap back
    final team = state.valueOrNull;
    if (team != null) {
      final squad = team.activeSquad;
      if (squad != null) {
        final updatedPlayers = squad.players.map((p) {
          final newOrder = battingOrderUpdates[p.id];
          if (newOrder != null && newOrder != p.battingOrder) {
            return SquadPlayer(
              id: p.id,
              squadId: p.squadId,
              userCardId: p.userCardId,
              position: p.position,
              isPlayingXI: p.isPlayingXI,
              isCaptain: p.isCaptain,
              isViceCaptain: p.isViceCaptain,
              battingOrder: newOrder,
              bowlingOrder: p.bowlingOrder,
              userCard: p.userCard,
            );
          }
          return p;
        }).toList();
        final updatedSquads = team.squads.map((s) {
          if (s.id == squad.id) {
            return Squad(
              id: s.id,
              teamId: s.teamId,
              squadName: s.squadName,
              formation: s.formation,
              isActive: s.isActive,
              players: updatedPlayers,
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

    // Persist batting_order to DB — no UNIQUE constraint, so no conflict risk.
    for (int i = 0; i < reordered.length; i++) {
      await SupabaseService.client
          .from('squad_players')
          .update({'batting_order': i + 1}).eq('id', reordered[i].id);
    }

    if (reordered.isNotEmpty) {
      await _normalizePlayingXIBattingOrder(reordered.first.squadId);
    }
    await loadTeam();
  }

  Future<void> refresh() => loadTeam();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// Chemistry calculation
final chemistryProvider = Provider<int>((ref) {
  final team = ref.watch(teamProvider).valueOrNull;
  if (team == null) return 0;
  final squad = team.activeSquad;
  if (squad == null) return 0;
  return _calculateChemistry(squad.playingXI);
});

int _calculateChemistry(List<SquadPlayer> playingXI) {
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
