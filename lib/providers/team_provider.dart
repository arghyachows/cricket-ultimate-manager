import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';

// Active team
final teamProvider =
    StateNotifierProvider<TeamNotifier, AsyncValue<Team?>>((ref) {
  return TeamNotifier();
});

class TeamNotifier extends StateNotifier<AsyncValue<Team?>> {
  TeamNotifier() : super(const AsyncValue.loading()) {
    loadTeam();
  }

  Future<void> loadTeam() async {
    try {
      state = const AsyncValue.loading();
      final data = await SupabaseService.getActiveTeam();
      if (data != null) {
        state = AsyncValue.data(Team.fromJson(data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Team?> createTeam(String name) async {
    try {
      final data = await SupabaseService.createTeam(name);
      final team = Team.fromJson(data);
      state = AsyncValue.data(team);
      return team;
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
    });
    await loadTeam();
  }

  Future<void> removePlayerFromSquad(String squadPlayerId) async {
    await SupabaseService.client
        .from('squad_players')
        .delete()
        .eq('id', squadPlayerId);
    await loadTeam();
  }

  Future<void> setPlayingXI(String squadPlayerId, bool isXI) async {
    await SupabaseService.client
        .from('squad_players')
        .update({'is_playing_xi': isXI}).eq('id', squadPlayerId);
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

  Future<void> setBattingOrder(String squadPlayerId, int order) async {
    await SupabaseService.client
        .from('squad_players')
        .update({'batting_order': order}).eq('id', squadPlayerId);
    await loadTeam();
  }

  Future<void> refresh() => loadTeam();
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
