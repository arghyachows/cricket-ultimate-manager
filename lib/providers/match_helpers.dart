import '../models/models.dart';
import 'match/match_state.dart';

/// Pure static helpers for match logic.
/// Kept outside match_state.dart to avoid import resolution issues.
class MatchHelpers {
  static Map<String, BatsmanStats> parseBatsmanStats(dynamic data) {
    final result = <String, BatsmanStats>{};
    if (data is! Map) return result;
    data.forEach((key, value) {
      final s = value as Map<String, dynamic>;
      result[key.toString()] = BatsmanStats(
        name: s['name'] ?? '', innings: s['innings'] ?? 1,
        battingOrder: s['battingOrder'] ?? 99, runs: s['runs'] ?? 0,
        balls: s['balls'] ?? 0, fours: s['fours'] ?? 0, sixes: s['sixes'] ?? 0,
        isOut: s['isOut'] ?? false, dismissalType: s['dismissalType'],
      );
    });
    return result;
  }

  static Map<String, BowlerStats> parseBowlerStats(dynamic data) {
    final result = <String, BowlerStats>{};
    if (data is! Map) return result;
    data.forEach((key, value) {
      final s = value as Map<String, dynamic>;
      result[key.toString()] = BowlerStats(
        name: s['name'] ?? '', innings: s['innings'] ?? 1,
        balls: s['balls'] ?? 0, runs: s['runs'] ?? 0,
        wickets: s['wickets'] ?? 0, maidens: s['maidens'] ?? 0,
        dotBalls: s['dotBalls'] ?? 0,
      );
    });
    return result;
  }

  static int inningsScoreFromEvents(List<MatchEvent> events, int inn) {
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  static String formatDismissal(String wicketType, String bowlerName, String? fielderName) {
    switch (wicketType) {
      case 'bowled': return 'b $bowlerName';
      case 'caught': return 'c ${fielderName ?? "fielder"} b $bowlerName';
      case 'caught_behind': return 'c ${fielderName ?? "†keeper"} b $bowlerName';
      case 'lbw': return 'lbw b $bowlerName';
      case 'run_out': return 'run out (${fielderName ?? "fielder"})';
      case 'stumped': return 'st ${fielderName ?? "†keeper"} b $bowlerName';
      default: return 'b $bowlerName';
    }
  }
}