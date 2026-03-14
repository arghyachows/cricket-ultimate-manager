import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

enum StatsSortField { runs, wickets, fours, sixes, catches, matches }

/// Aggregates career stats from in-memory match history for all user players.
final careerStatsProvider = Provider.family<List<PlayerCareerStats>, StatsSortField>((ref, sortField) {
  final history = ref.watch(matchHistoryProvider);
  final statsMap = <String, PlayerCareerStats>{};

  for (final match in history) {
    // Track which userCardIds appeared in this match (to count matches played)
    final matchPlayers = <String>{};

    // Aggregate batting stats
    for (final entry in match.batsmanStats.entries) {
      // Key format: "${innings}_${userCardId}"
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final userCardId = parts.sublist(1).join('_');
      // Skip AI players
      if (userCardId.startsWith('ai_')) continue;

      final bat = entry.value;
      final stats = statsMap.putIfAbsent(
        userCardId,
        () => PlayerCareerStats(userCardId: userCardId, playerName: bat.name),
      );
      matchPlayers.add(userCardId);
      stats.runs += bat.runs;
      stats.ballsFaced += bat.balls;
      stats.fours += bat.fours;
      stats.sixes += bat.sixes;
      if (bat.runs > stats.highScore) stats.highScore = bat.runs;
    }

    // Aggregate bowling stats
    for (final entry in match.bowlerStats.entries) {
      final parts = entry.key.split('_');
      if (parts.length < 2) continue;
      final userCardId = parts.sublist(1).join('_');
      if (userCardId.startsWith('ai_')) continue;

      final bowl = entry.value;
      final stats = statsMap.putIfAbsent(
        userCardId,
        () => PlayerCareerStats(userCardId: userCardId, playerName: bowl.name),
      );
      matchPlayers.add(userCardId);
      stats.wickets += bowl.wickets;
      stats.ballsBowled += bowl.balls;
      stats.runsConceded += bowl.runs;
      if (bowl.wickets > stats.bestBowlingWickets) {
        stats.bestBowlingWickets = bowl.wickets;
      }
    }

    // Count catches from events
    for (final event in match.events) {
      if (event.isWicket && event.fielderCardId != null) {
        final fid = event.fielderCardId!;
        if (fid.startsWith('ai_')) continue;
        final wicketType = event.wicketType ?? '';
        if (wicketType == 'caught' || wicketType == 'caught_behind') {
          final stats = statsMap[fid];
          if (stats != null) {
            stats.catches++;
          }
        }
      }
    }

    // Increment matches played
    for (final id in matchPlayers) {
      statsMap[id]!.matches++;
    }
  }

  // Sort
  final list = statsMap.values.toList();
  switch (sortField) {
    case StatsSortField.runs:
      list.sort((a, b) => b.runs.compareTo(a.runs));
      break;
    case StatsSortField.wickets:
      list.sort((a, b) => b.wickets.compareTo(a.wickets));
      break;
    case StatsSortField.fours:
      list.sort((a, b) => b.fours.compareTo(a.fours));
      break;
    case StatsSortField.sixes:
      list.sort((a, b) => b.sixes.compareTo(a.sixes));
      break;
    case StatsSortField.catches:
      list.sort((a, b) => b.catches.compareTo(a.catches));
      break;
    case StatsSortField.matches:
      list.sort((a, b) => b.matches.compareTo(a.matches));
      break;
  }

  return list;
});
