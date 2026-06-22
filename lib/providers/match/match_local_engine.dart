import 'dart:async';
import '../../models/models.dart';
import '../../engine/match_engine.dart';
import '../match_helpers.dart';
import 'match_state.dart';

/// Handles local engine match simulation (ball-by-ball + skip-to-end).
class MatchLocalEngine {
  MatchEngine? _engine;
  Timer? _simulationTimer;
  final void Function(MatchEvent result) onBallSimulated;
  final void Function() onMatchComplete;

  MatchLocalEngine({
    required this.onBallSimulated,
    required this.onMatchComplete,
  });

  MatchEngine? get engine => _engine;

  void start({
    required List<LineupPlayer> homeXI,
    required List<LineupPlayer> awayXI,
    required int homeChemistry,
    required int awayChemistry,
    required String homeTeamName,
    required String awayTeamName,
    required int overs,
    required String pitchCondition,
    required bool homeBatsFirst,
  }) {
    _engine = MatchEngine(
      homeXI: homeXI,
      awayXI: awayXI,
      homeChemistry: homeChemistry,
      awayChemistry: awayChemistry,
      overs: overs,
      pitchCondition: pitchCondition,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      homeBatsFirst: homeBatsFirst,
    );

    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) => _simulateNextBall(),
    );
  }

  MatchEvent? simulateNextBall() {
    if (_engine == null) return null;
    return _engine!.simulateNextBall();
  }

  void _simulateNextBall() {
    final result = simulateNextBall();
    if (result == null) {
      _simulationTimer?.cancel();
      onMatchComplete();
      return;
    }
    onBallSimulated(result);
  }

  void cancel() {
    _simulationTimer?.cancel();
    _engine = null;
  }

  /// Compute full final MatchState after skipping to end of match.
  /// Call this after cancel();, with the current engine and existing state.
  static MatchState computeSkipToEndResult(MatchState currentState, MatchEngine engine) {
    final batsmanStats = Map<String, BatsmanStats>.from(currentState.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(currentState.bowlerStats);
    final allEvents = <MatchEvent>[...currentState.events];

    while (true) {
      final result = engine.simulateNextBall();
      if (result == null) break;
      allEvents.add(result);
      _applyEventResult(result, engine, batsmanStats, bowlerStats);
    }

    return currentState.copyWith(
      events: allEvents,
      isSimulating: false,
      currentCommentary: engine.getMatchResult(),
      currentInnings: allEvents.isNotEmpty ? allEvents.last.innings : currentState.currentInnings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
    );
  }

  static void _applyEventResult(
    MatchEvent result,
    MatchEngine engine,
    Map<String, BatsmanStats> batsmanStats,
    Map<String, BowlerStats> bowlerStats,
  ) {
    if (result.eventType == 'innings_break') return;

    final isExtra = result.eventType == 'wide' || result.eventType == 'no_ball';
    final batKey = '${result.innings}_${result.batsmanCardId}';
    final bowlKey = '${result.innings}_${result.bowlerCardId}';

    batsmanStats.putIfAbsent(batKey,
        () => BatsmanStats(name: engine.getBatsmanName(result.batsmanCardId), innings: result.innings));
    final bat = batsmanStats[batKey]!;
    if (!isExtra) bat.balls++;
    if (!isExtra) bat.runs += result.runs;
    if (result.runs == 4) bat.fours++;
    if (result.runs == 6) bat.sixes++;
    if (result.isWicket) {
      bat.isOut = true;
      bat.dismissalType = MatchHelpers.formatDismissal(
        result.wicketType ?? 'bowled',
        engine.getBowlerName(result.bowlerCardId),
        result.fielderCardId != null ? engine.getBatsmanName(result.fielderCardId!) : null,
      );
    }

    final sId = engine.currentStrikerCardId;
    final nsId = engine.currentNonStrikerCardId;
    if (sId != null) {
      batsmanStats.putIfAbsent('${result.innings}_$sId',
          () => BatsmanStats(name: engine.getBatsmanName(sId), innings: result.innings));
    }
    if (nsId != null) {
      batsmanStats.putIfAbsent('${result.innings}_$nsId',
          () => BatsmanStats(name: engine.getBatsmanName(nsId), innings: result.innings));
    }

    bowlerStats.putIfAbsent(bowlKey,
        () => BowlerStats(name: engine.getBowlerName(result.bowlerCardId), innings: result.innings));
    final bowl = bowlerStats[bowlKey]!;
    if (!isExtra) bowl.balls++;
    bowl.runs += result.runs;
    if (result.isWicket) bowl.wickets++;
    if (result.runs == 0 && !result.isWicket && !isExtra) bowl.dotBalls++;
  }

  /// Apply a single ball result to the current state and return the updated state.
  static MatchState applyBallResult(MatchState currentState, MatchEvent result, MatchEngine engine) {
    final events = [...currentState.events, result];
    final batsmanStats = Map<String, BatsmanStats>.from(currentState.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(currentState.bowlerStats);

    if (result.eventType != 'innings_break') {
      final isExtra = result.eventType == 'wide' || result.eventType == 'no_ball';
      final batKey = '${result.innings}_${result.batsmanCardId}';
      final bowlKey = '${result.innings}_${result.bowlerCardId}';

      final batName = engine.getBatsmanName(result.batsmanCardId);
      batsmanStats.putIfAbsent(batKey, () => BatsmanStats(name: batName, innings: result.innings));
      final bat = batsmanStats[batKey]!;
      if (!isExtra) bat.balls++;
      if (!isExtra) bat.runs += result.runs;
      if (result.runs == 4) bat.fours++;
      if (result.runs == 6) bat.sixes++;
      if (result.isWicket) {
        bat.isOut = true;
        bat.dismissalType = MatchHelpers.formatDismissal(
          result.wicketType ?? 'bowled',
          engine.getBowlerName(result.bowlerCardId),
          result.fielderCardId != null ? engine.getBatsmanName(result.fielderCardId!) : null,
        );
      }

      final sId = engine.currentStrikerCardId;
      final nsId = engine.currentNonStrikerCardId;
      if (sId != null) {
        batsmanStats.putIfAbsent('${result.innings}_$sId',
            () => BatsmanStats(name: engine.getBatsmanName(sId), innings: result.innings));
      }
      if (nsId != null) {
        batsmanStats.putIfAbsent('${result.innings}_$nsId',
            () => BatsmanStats(name: engine.getBatsmanName(nsId), innings: result.innings));
      }

      bowlerStats.putIfAbsent(bowlKey,
          () => BowlerStats(name: engine.getBowlerName(result.bowlerCardId), innings: result.innings));
      final bowl = bowlerStats[bowlKey]!;
      if (!isExtra) bowl.balls++;
      bowl.runs += result.runs;
      if (result.isWicket) bowl.wickets++;
      if (result.runs == 0 && !result.isWicket && !isExtra) bowl.dotBalls++;
    }

    final newTarget = (result.innings == 2 && currentState.target == 0)
        ? MatchHelpers.inningsScoreFromEvents([...currentState.events, result], 1)
        : currentState.target;

    return currentState.copyWith(
      events: events,
      currentCommentary: result.commentary,
      currentInnings: result.innings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
      target: newTarget,
      strikerCardId: result.eventType != 'innings_break' ? (engine.currentStrikerCardId ?? '') : '',
      nonStrikerCardId: result.eventType != 'innings_break' ? (engine.currentNonStrikerCardId ?? '') : '',
    );
  }
}