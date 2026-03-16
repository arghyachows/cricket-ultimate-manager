import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import 'match_provider.dart';

/// Aggregated career stats for a single player card across all matches.
class PlayerCareerStats {
  final String userCardId;
  final String playerName;
  int matches;
  int runs;
  int ballsFaced;
  int fours;
  int sixes;
  int wickets;
  int ballsBowled;
  int runsConceded;
  int catches;
  int highScore;
  int bestBowlingWickets;

  PlayerCareerStats({
    required this.userCardId,
    required this.playerName,
    this.matches = 0,
    this.runs = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.wickets = 0,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.catches = 0,
    this.highScore = 0,
    this.bestBowlingWickets = 0,
  });

  double get battingAvg => matches > 0 ? runs / matches : 0;
  double get strikeRate => ballsFaced > 0 ? (runs / ballsFaced) * 100 : 0;
  double get bowlingEconomy {
    final overs = ballsBowled / 6;
    return overs > 0 ? runsConceded / overs : 0;
  }

  factory PlayerCareerStats.fromJson(Map<String, dynamic> json) {
    return PlayerCareerStats(
      userCardId: json['user_card_id'] ?? '',
      playerName: json['player_name'] ?? '',
      matches: json['matches'] ?? 0,
      runs: json['runs'] ?? 0,
      ballsFaced: json['balls_faced'] ?? 0,
      fours: json['fours'] ?? 0,
      sixes: json['sixes'] ?? 0,
      wickets: json['wickets'] ?? 0,
      ballsBowled: json['balls_bowled'] ?? 0,
      runsConceded: json['runs_conceded'] ?? 0,
      catches: json['catches'] ?? 0,
      highScore: json['high_score'] ?? 0,
      bestBowlingWickets: json['best_bowling_wickets'] ?? 0,
    );
  }
}

enum StatsSortField { runs, wickets, fours, sixes, catches, matches }

/// Notifier that loads career stats from Supabase and persists after matches.
class CareerStatsNotifier extends StateNotifier<List<PlayerCareerStats>> {
  CareerStatsNotifier() : super([]) {
    loadFromDb();
  }

  Future<void> loadFromDb() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final rows = await SupabaseService.client
          .from('user_player_stats')
          .select()
          .eq('user_id', userId)
          .order('runs', ascending: false);
      state = (rows as List).map((r) => PlayerCareerStats.fromJson(r)).toList();
    } catch (_) {
      // Table may not exist yet; keep empty
    }
  }

  /// Persist stats delta from a single completed match.
  Future<void> persistMatchStats(MatchSummary match) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    // Fetch the current user's own card IDs to avoid recording opponent stats
    // (in multiplayer both teams have real UUIDs, so we must filter by ownership)
    Set<String>? myCardIds;
    try {
      final rows = await SupabaseService.client
          .from('user_cards')
          .select('id')
          .eq('user_id', userId);
      myCardIds = Set<String>.from((rows as List).map((r) => r['id'].toString()));
    } catch (_) {
      // If lookup fails, fall back to the AI-prefix filter only
    }

    // Aggregate per-player deltas from this match
    final deltas = <String, PlayerCareerStats>{};

    // Batting stats
    for (final entry in match.batsmanStats.entries) {
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final userCardId = parts.sublist(1).join('_');
      if (userCardId.startsWith('ai')) continue;
      if (myCardIds != null && !myCardIds.contains(userCardId)) continue;

      final bat = entry.value;
      final d = deltas.putIfAbsent(
        userCardId,
        () => PlayerCareerStats(userCardId: userCardId, playerName: bat.name),
      );
      d.runs += bat.runs;
      d.ballsFaced += bat.balls;
      d.fours += bat.fours;
      d.sixes += bat.sixes;
      if (bat.runs > d.highScore) d.highScore = bat.runs;
    }

    // Bowling stats
    for (final entry in match.bowlerStats.entries) {
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final userCardId = parts.sublist(1).join('_');
      if (userCardId.startsWith('ai')) continue;
      if (myCardIds != null && !myCardIds.contains(userCardId)) continue;

      final bowl = entry.value;
      final d = deltas.putIfAbsent(
        userCardId,
        () => PlayerCareerStats(userCardId: userCardId, playerName: bowl.name),
      );
      d.wickets += bowl.wickets;
      d.ballsBowled += bowl.balls;
      d.runsConceded += bowl.runs;
      if (bowl.wickets > d.bestBowlingWickets) d.bestBowlingWickets = bowl.wickets;
    }

    // Catches
    for (final event in match.events) {
      if (event.isWicket && event.fielderCardId != null) {
        final fid = event.fielderCardId!;
        if (fid.startsWith('ai')) continue;
        if (myCardIds != null && !myCardIds.contains(fid)) continue;
        final wicketType = event.wicketType ?? '';
        if (wicketType == 'caught' || wicketType == 'caught_behind') {
          final d = deltas[fid];
          if (d != null) d.catches++;
        }
      }
    }

    // Mark matches played
    for (final d in deltas.values) {
      d.matches = 1;
    }

    // Upsert each player to DB
    for (final d in deltas.values) {
      try {
        await SupabaseService.client.rpc('upsert_player_stats', params: {
          'p_user_id': userId,
          'p_user_card_id': d.userCardId,
          'p_player_name': d.playerName,
          'p_matches': d.matches,
          'p_runs': d.runs,
          'p_balls_faced': d.ballsFaced,
          'p_fours': d.fours,
          'p_sixes': d.sixes,
          'p_wickets': d.wickets,
          'p_balls_bowled': d.ballsBowled,
          'p_runs_conceded': d.runsConceded,
          'p_catches': d.catches,
          'p_high_score': d.highScore,
          'p_best_bowling_wickets': d.bestBowlingWickets,
        });
      } catch (_) {
        // Silently fail for individual players
      }
    }

    // Reload from DB to get fresh totals
    await loadFromDb();
  }
}

final careerStatsNotifierProvider =
    StateNotifierProvider<CareerStatsNotifier, List<PlayerCareerStats>>(
  (ref) => CareerStatsNotifier(),
);

/// Sorted view of career stats.
final careerStatsProvider =
    Provider.family<List<PlayerCareerStats>, StatsSortField>((ref, sortField) {
  final stats = List<PlayerCareerStats>.from(ref.watch(careerStatsNotifierProvider));

  switch (sortField) {
    case StatsSortField.runs:
      stats.sort((a, b) => b.runs.compareTo(a.runs));
      break;
    case StatsSortField.wickets:
      stats.sort((a, b) => b.wickets.compareTo(a.wickets));
      break;
    case StatsSortField.fours:
      stats.sort((a, b) => b.fours.compareTo(a.fours));
      break;
    case StatsSortField.sixes:
      stats.sort((a, b) => b.sixes.compareTo(a.sixes));
      break;
    case StatsSortField.catches:
      stats.sort((a, b) => b.catches.compareTo(a.catches));
      break;
    case StatsSortField.matches:
      stats.sort((a, b) => b.matches.compareTo(a.matches));
      break;
  }

  return stats;
});
