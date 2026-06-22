import '../../models/models.dart';
import '../match_helpers.dart';
import 'match_phase.dart';
import 'match_state.dart';

/// Computed properties for [MatchState].
/// Kept in a separate file so the Dart analyzer can resolve freezed-generated
/// members (phase, copyWith, etc.) without part-file resolution issues.
extension MatchStateComputed on MatchState {
  /// Returns a new [MatchState] with [phase] set to [newPhase].
  /// If the transition is invalid, returns the current state unchanged.
  MatchState transitionTo(MatchPhase newPhase) {
    if (!MatchState.isValidTransition(phase, newPhase)) return this;
    return copyWith(phase: newPhase);
  }

  /// Events from the regular match only (excluding super over).
  List<MatchEvent> get _regularEvents {
    final idx = events.indexWhere((e) => e.eventType == 'super_over');
    return idx < 0 ? events : events.sublist(0, idx);
  }

  /// True when a match is in progress or just completed.
  bool get hasActiveMatch => isSimulating || isMatchComplete;

  int _inningsScore(int inn) =>
      MatchHelpers.inningsScoreFromEvents(_regularEvents, inn);

  int _inningsWickets(int inn) {
    final innEvents = _regularEvents.where((e) => e.innings == inn);
    return innEvents.isEmpty ? 0 : (innEvents.last.wicketsAfter);
  }

  String _inningsOvers(int inn) {
    final innEvents = _regularEvents.where((e) =>
        e.innings == inn &&
        e.eventType != 'wide' &&
        e.eventType != 'no_ball' &&
        e.eventType != 'innings_break');
    if (innEvents.isEmpty) return '0.0';
    final last = innEvents.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  int get _homeInningsNum => homeBatsFirst ? 1 : 2;
  int get _awayInningsNum => homeBatsFirst ? 2 : 1;

  /// Home team's total runs.
  int get homeScore => _inningsScore(_homeInningsNum);

  /// Home team's wickets fallen.
  int get homeWickets => _inningsWickets(_homeInningsNum);

  /// Home team's overs bowled (e.g. '12.3').
  String get homeOvers => _inningsOvers(_homeInningsNum);

  /// Away team's total runs.
  int get awayScore => _inningsScore(_awayInningsNum);

  /// Away team's wickets fallen.
  int get awayWickets => _inningsWickets(_awayInningsNum);

  /// Away team's overs bowled.
  String get awayOvers => _inningsOvers(_awayInningsNum);

  /// Current innings overs display.
  String get currentOvers => _inningsOvers(currentInnings);

  /// Batsmen currently at the crease (current innings, not out).
  List<BatsmanStats> get currentBatsmen {
    final current = batsmanStats.values
        .where((b) => b.innings == currentInnings && !b.isOut)
        .toList();
    return _orderByXi(current, currentInnings == 1 ? xiOrder1 : xiOrder2);
  }

  /// Bowlers who have bowled in the current innings.
  List<BowlerStats> get currentBowlers =>
      bowlerStats.values.where((b) => b.innings == currentInnings).toList();

  List<BatsmanStats> _orderByXi(
      List<BatsmanStats> batsmen, List<String> xiOrder) {
    if (xiOrder.isEmpty) return batsmen;
    final ordered = <BatsmanStats>[];
    final remaining = List<BatsmanStats>.from(batsmen);
    for (final name in xiOrder) {
      final idx = remaining.indexWhere((b) => b.name == name);
      if (idx >= 0) {
        ordered.add(remaining.removeAt(idx));
      }
    }
    ordered.addAll(remaining);
    return ordered;
  }

  /// All batsmen from innings 1, ordered by xiOrder1.
  List<BatsmanStats> get innings1Batsmen {
    final inn1 = batsmanStats.values.where((b) => b.innings == 1).toList();
    return _orderByXi(inn1, xiOrder1);
  }

  /// All batsmen from innings 2, ordered by xiOrder2.
  List<BatsmanStats> get innings2Batsmen {
    final inn2 = batsmanStats.values.where((b) => b.innings == 2).toList();
    return _orderByXi(inn2, xiOrder2);
  }

  /// All bowlers from innings 1.
  List<BowlerStats> get innings1Bowlers =>
      bowlerStats.values.where((b) => b.innings == 1).toList();

  /// All bowlers from innings 2.
  List<BowlerStats> get innings2Bowlers =>
      bowlerStats.values.where((b) => b.innings == 2).toList();

  /// Runs needed to win (only meaningful in 2nd innings when chasing).
  int get runsNeeded {
    if (currentInnings < 2 || target == 0) return 0;
    final current = _inningsScore(currentInnings);
    final needed = (target + 1) - current;
    return needed > 0 ? needed : 0;
  }

  /// Balls remaining in the current innings.
  int get ballsRemaining {
    final totalBalls = matchOvers * 6;
    final bowled = _regularEvents
        .where((e) =>
            e.innings == currentInnings &&
            e.eventType != 'wide' &&
            e.eventType != 'no_ball' &&
            e.eventType != 'innings_break')
        .length;
    final remaining = totalBalls - bowled;
    return remaining > 0 ? remaining : 0;
  }

  /// Required run rate to win.
  double get requiredRunRate {
    final balls = ballsRemaining;
    if (balls <= 0) return 0;
    return (runsNeeded / balls) * 6;
  }

  /// Returns a copy with level-up pack cleared.
  MatchState clearLevelUpPack() {
    return copyWith(
      levelUpPackAwarded: null,
      newLevel: null,
    );
  }
}
