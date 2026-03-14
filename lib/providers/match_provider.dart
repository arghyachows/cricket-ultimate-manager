import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../engine/match_engine.dart';
import 'auth_provider.dart';

// Match state
final matchProvider =
    StateNotifierProvider<MatchNotifier, MatchState>((ref) {
  return MatchNotifier(ref);
});

class MatchState {
  final MatchModel? match;
  final List<MatchEvent> events;
  final bool isSimulating;
  final bool isMatchComplete;
  final String? currentCommentary;
  final int currentInnings;
  final Map<String, BatsmanStats> batsmanStats;
  final Map<String, BowlerStats> bowlerStats;
  final String homeTeamName;
  final String awayTeamName;
  final String matchFormat;
  final int matchOvers;
  final String matchDifficulty;
  /// true = home won, false = away won, null = tie or not finished
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;
  final String pitchCondition;
  final String weatherCondition;
  final bool userWonToss;
  final String tossDecision; // 'bat' or 'bowl'
  final bool homeBatsFirst;
  final int target;

  const MatchState({
    this.match,
    this.events = const [],
    this.isSimulating = false,
    this.isMatchComplete = false,
    this.currentCommentary,
    this.currentInnings = 1,
    this.batsmanStats = const {},
    this.bowlerStats = const {},
    this.homeTeamName = '',
    this.awayTeamName = '',
    this.matchFormat = 't20',
    this.matchOvers = 20,
    this.matchDifficulty = 'Village',
    this.homeWon,
    this.coinsAwarded = 0,
    this.xpAwarded = 0,
    this.pitchCondition = 'balanced',
    this.weatherCondition = 'clear',
    this.userWonToss = true,
    this.tossDecision = 'bat',
    this.homeBatsFirst = true,
    this.target = 0,
  });

  bool get hasActiveMatch => isSimulating || isMatchComplete;

  /// Helper to get score for a specific innings
  int _inningsScore(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  int _inningsWickets(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.wicketsAfter;
  }

  String _inningsOvers(int inn) {
    final inns = events.where((e) => e.innings == inn);
    if (inns.isEmpty) return '0.0';
    final last = inns.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  /// Home team's score (accounts for batting order)
  int get homeScore => homeBatsFirst ? _inningsScore(1) : _inningsScore(2);
  int get homeWickets => homeBatsFirst ? _inningsWickets(1) : _inningsWickets(2);
  String get homeOvers => homeBatsFirst ? _inningsOvers(1) : _inningsOvers(2);

  /// Away team's score (accounts for batting order)
  int get awayScore => homeBatsFirst ? _inningsScore(2) : _inningsScore(1);
  int get awayWickets => homeBatsFirst ? _inningsWickets(2) : _inningsWickets(1);
  String get awayOvers => homeBatsFirst ? _inningsOvers(2) : _inningsOvers(1);

  String get currentOvers {
    if (events.isEmpty) return '0.0';
    final last = events.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  /// Batsmen who batted in innings 1 (home team)
  List<BatsmanStats> get innings1Batsmen =>
      batsmanStats.values.where((b) => b.innings == 1).toList();

  /// Batsmen who batted in innings 2 (away team)
  List<BatsmanStats> get innings2Batsmen =>
      batsmanStats.values.where((b) => b.innings == 2).toList();

  /// Bowlers who bowled in innings 1 (away team bowled)
  List<BowlerStats> get innings1Bowlers =>
      bowlerStats.values.where((b) => b.innings == 1).toList();

  /// Bowlers who bowled in innings 2 (home team bowled)
  List<BowlerStats> get innings2Bowlers =>
      bowlerStats.values.where((b) => b.innings == 2).toList();

  /// Currently batting batsmen (current innings, not out)
  List<BatsmanStats> get currentBatsmen =>
      batsmanStats.values
          .where((b) => b.innings == currentInnings && !b.isOut)
          .toList();

  /// Current bowler stats (current innings bowlers)
  List<BowlerStats> get currentBowlers =>
      bowlerStats.values.where((b) => b.innings == currentInnings).toList();

  /// Runs needed to win (only valid in 2nd innings)
  int get runsNeeded {
    if (currentInnings < 2 || target == 0) return 0;
    // The chasing team's score is always innings 2
    final chasingScore = _inningsScore(2);
    final needed = target + 1 - chasingScore;
    return needed > 0 ? needed : 0;
  }

  /// Balls remaining in current innings
  int get ballsRemaining {
    if (events.isEmpty) return maxOversForFormat * 6;
    final inningsEvents = events.where((e) => e.innings == currentInnings);
    if (inningsEvents.isEmpty) return maxOversForFormat * 6;
    final last = inningsEvents.last;
    final ballsBowled = last.overNumber * 6 + last.ballNumber;
    return (maxOversForFormat * 6) - ballsBowled;
  }

  int get maxOversForFormat => matchFormat == 'odi' ? 50 : 20;

  /// Required run rate (only in 2nd innings)
  double get requiredRunRate {
    if (currentInnings < 2 || ballsRemaining <= 0) return 0;
    return (runsNeeded / ballsRemaining) * 6;
  }

  MatchState copyWith({
    MatchModel? match,
    List<MatchEvent>? events,
    bool? isSimulating,
    bool? isMatchComplete,
    String? currentCommentary,
    int? currentInnings,
    Map<String, BatsmanStats>? batsmanStats,
    Map<String, BowlerStats>? bowlerStats,
    String? homeTeamName,
    String? awayTeamName,
    String? matchFormat,
    int? matchOvers,
    String? matchDifficulty,
    bool? homeWon,
    int? coinsAwarded,
    int? xpAwarded,
    String? pitchCondition,
    String? weatherCondition,
    bool? userWonToss,
    String? tossDecision,
    bool? homeBatsFirst,
    int? target,
  }) {
    return MatchState(
      match: match ?? this.match,
      events: events ?? this.events,
      isSimulating: isSimulating ?? this.isSimulating,
      isMatchComplete: isMatchComplete ?? this.isMatchComplete,
      currentCommentary: currentCommentary ?? this.currentCommentary,
      currentInnings: currentInnings ?? this.currentInnings,
      batsmanStats: batsmanStats ?? this.batsmanStats,
      bowlerStats: bowlerStats ?? this.bowlerStats,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      matchFormat: matchFormat ?? this.matchFormat,
      matchOvers: matchOvers ?? this.matchOvers,
      matchDifficulty: matchDifficulty ?? this.matchDifficulty,
      homeWon: homeWon ?? this.homeWon,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      pitchCondition: pitchCondition ?? this.pitchCondition,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      userWonToss: userWonToss ?? this.userWonToss,
      tossDecision: tossDecision ?? this.tossDecision,
      homeBatsFirst: homeBatsFirst ?? this.homeBatsFirst,
      target: target ?? this.target,
    );
  }
}

class BatsmanStats {
  final String name;
  final int innings;
  int runs;
  int balls;
  int fours;
  int sixes;
  bool isOut;
  String? dismissalType;

  BatsmanStats({required this.name, required this.innings, this.runs = 0, this.balls = 0, this.fours = 0, this.sixes = 0, this.isOut = false, this.dismissalType});

  double get strikeRate => balls > 0 ? (runs / balls) * 100 : 0;
}

class BowlerStats {
  final String name;
  final int innings;
  int overs;
  int balls;
  int runs;
  int wickets;
  int maidens;
  int dotBalls;

  BowlerStats({required this.name, required this.innings, this.overs = 0, this.balls = 0, this.runs = 0, this.wickets = 0, this.maidens = 0, this.dotBalls = 0});

  double get economy {
    final fullOvers = balls ~/ 6;
    final remainingBalls = balls % 6;
    final totalOvers = fullOvers + (remainingBalls / 6);
    return totalOvers > 0 ? runs / totalOvers : 0;
  }

  String get oversDisplay {
    final fullOvers = balls ~/ 6;
    final remainingBalls = balls % 6;
    return '$fullOvers.$remainingBalls';
  }
}

/// Summary of a completed match for history
class MatchSummary {
  final String homeTeamName;
  final String awayTeamName;
  final String format;
  final int homeScore;
  final int homeWickets;
  final String homeOvers;
  final int awayScore;
  final int awayWickets;
  final String awayOvers;
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;
  final DateTime playedAt;
  final Map<String, BatsmanStats> batsmanStats;
  final Map<String, BowlerStats> bowlerStats;
  final List<MatchEvent> events;

  const MatchSummary({
    required this.homeTeamName,
    required this.awayTeamName,
    required this.format,
    required this.homeScore,
    required this.homeWickets,
    required this.homeOvers,
    required this.awayScore,
    required this.awayWickets,
    required this.awayOvers,
    required this.homeWon,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.playedAt,
    required this.batsmanStats,
    required this.bowlerStats,
    required this.events,
  });

  String get resultText {
    if (homeWon == true) {
      final wicketsRemaining = 10 - awayWickets;
      return '$awayTeamName won by $wicketsRemaining wickets' == ''
          ? '$homeTeamName won!'
          : '$homeTeamName won!';
    } else if (homeWon == false) {
      return '$awayTeamName won!';
    }
    return 'Match Drawn';
  }
}

class MatchNotifier extends StateNotifier<MatchState> {
  final Ref ref;
  Timer? _simulationTimer;
  MatchEngine? _engine;

  MatchNotifier(this.ref) : super(const MatchState());

  static int _inningsScoreFromEvents(List<MatchEvent> events, int inn) {
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  /// In-memory match history
  final List<MatchSummary> _matchHistory = [];
  List<MatchSummary> get matchHistory => List.unmodifiable(_matchHistory);

  Future<void> startMatch({
    required List<SquadPlayer> homeXI,
    required List<SquadPlayer> awayXI,
    required String homeTeamId,
    required String awayTeamId,
    required int homeChemistry,
    required int awayChemistry,
    required String homeTeamName,
    required String awayTeamName,
    int overs = 20,
    String difficulty = 'Village',
    String pitchCondition = 'balanced',
    String weatherCondition = 'clear',
    bool userWonToss = true,
    String tossDecision = 'bat',
    bool homeBatsFirst = true,
  }) async {
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

    state = MatchState(
      isSimulating: true,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      matchFormat: overs >= 50 ? 'odi' : overs >= 20 ? 't20' : 'quick',
      matchOvers: overs,
      matchDifficulty: difficulty,
      pitchCondition: pitchCondition,
      weatherCondition: weatherCondition,
      userWonToss: userWonToss,
      tossDecision: tossDecision,
      homeBatsFirst: homeBatsFirst,
    );

    // Simulate ball by ball with delay for UX
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _simulateNextBall(),
    );
  }

  String _formatDismissal(String wicketType, String bowlerName, String? fielderName) {
    switch (wicketType) {
      case 'bowled':
        return 'b $bowlerName';
      case 'caught':
        return 'c ${fielderName ?? "fielder"} b $bowlerName';
      case 'caught_behind':
        return 'c ${fielderName ?? "†keeper"} b $bowlerName';
      case 'lbw':
        return 'lbw b $bowlerName';
      case 'run_out':
        return 'run out (${fielderName ?? "fielder"})';
      case 'stumped':
        return 'st ${fielderName ?? "†keeper"} b $bowlerName';
      default:
        return 'b $bowlerName';
    }
  }

  void _simulateNextBall() {
    if (_engine == null) return;

    final result = _engine!.simulateNextBall();
    if (result == null) {
      // Match complete
      _simulationTimer?.cancel();
      state = state.copyWith(
        isSimulating: false,
        currentCommentary: _engine!.getMatchResult(),
      );
      _onMatchComplete();
      return;
    }

    final events = [...state.events, result];
    final batsmanStats = Map<String, BatsmanStats>.from(state.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(state.bowlerStats);

    // Skip stats processing for innings-break synthetic events
    if (result.eventType != 'innings_break') {
      final isExtra = result.eventType == 'wide' || result.eventType == 'no_ball';

      // Use compound key: innings_cardId to separate per-innings stats
      final batKey = '${result.innings}_${result.batsmanCardId}';
      final bowlKey = '${result.innings}_${result.bowlerCardId}';

      // Update batsman stats
      final batsmanName =
          _engine!.getBatsmanName(result.batsmanCardId);
      batsmanStats.putIfAbsent(
          batKey, () => BatsmanStats(name: batsmanName, innings: result.innings));
      final batStats = batsmanStats[batKey]!;
      if (result.eventType != 'wide') batStats.balls++; // wides don't count as balls faced
      batStats.runs += result.runs;
      if (result.runs == 4) batStats.fours++;
      if (result.runs == 6) batStats.sixes++;
      if (result.isWicket) {
        batStats.isOut = true;
        final bowlerNameForDismissal = _engine!.getBowlerName(result.bowlerCardId);
        final fielderNameForDismissal = result.fielderCardId != null
            ? _engine!.getBatsmanName(result.fielderCardId!)
            : null;
        batStats.dismissalType = _formatDismissal(
          result.wicketType ?? 'bowled',
          bowlerNameForDismissal,
          fielderNameForDismissal,
        );
      }

      // Update bowler stats
      final bowlerName = _engine!.getBowlerName(result.bowlerCardId);
      bowlerStats.putIfAbsent(
          bowlKey, () => BowlerStats(name: bowlerName, innings: result.innings));
      final bowlStats = bowlerStats[bowlKey]!;
      if (!isExtra) bowlStats.balls++; // wides/no-balls are not legal deliveries
      bowlStats.runs += result.runs;
      if (result.isWicket) bowlStats.wickets++;
      if (result.runs == 0 && !result.isWicket && !isExtra) {
        bowlStats.dotBalls++;
      }
    }

    // Track target when innings changes to 2nd (target = innings 1 score)
    final newTarget = (result.innings == 2 && state.target == 0)
        ? _inningsScoreFromEvents([...state.events, result], 1)
        : null;

    state = state.copyWith(
      events: events,
      currentCommentary: result.commentary,
      currentInnings: result.innings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
      target: newTarget,
    );
  }

  void _onMatchComplete() {
    if (_engine == null) return;

    // Determine winner — score1 is batting-first team, score2 is batting-second
    final score1 = _engine!.score1;
    final score2 = _engine!.score2;
    final homeBatsFirst = state.homeBatsFirst;

    // Home score depends on batting order
    final homeTotal = homeBatsFirst ? score1 : score2;
    final awayTotal = homeBatsFirst ? score2 : score1;

    bool? homeWon;
    int coins;
    int xp;

    // Coin multipliers based on difficulty and overs
    double diffMultiplier;
    switch (state.matchDifficulty) {
      case 'Village': diffMultiplier = 0.5; break;
      case 'Domestic': diffMultiplier = 1.0; break;
      case 'International': diffMultiplier = 2.0; break;
      default: diffMultiplier = 1.0;
    }
    double oversMultiplier;
    switch (state.matchOvers) {
      case 5: oversMultiplier = 0.25; break;
      case 10: oversMultiplier = 0.5; break;
      case 20: oversMultiplier = 1.0; break;
      case 50: oversMultiplier = 2.0; break;
      default: oversMultiplier = 1.0;
    }

    if (homeTotal > awayTotal) {
      homeWon = true;
      coins = (AppConstants.matchWinCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchWinXP;
    } else if (awayTotal > homeTotal) {
      homeWon = false;
      coins = (AppConstants.matchLoseCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchPlayXP;
    } else {
      homeWon = null;
      coins = (AppConstants.matchDrawCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchPlayXP + 20;
    }

    state = state.copyWith(
      homeWon: homeWon,
      coinsAwarded: coins,
      xpAwarded: xp,
      isMatchComplete: true,
    );

    // Save to match history
    _matchHistory.insert(0, MatchSummary(
      homeTeamName: state.homeTeamName,
      awayTeamName: state.awayTeamName,
      format: state.matchFormat,
      homeScore: state.homeScore,
      homeWickets: state.homeWickets,
      homeOvers: state.homeOvers,
      awayScore: state.awayScore,
      awayWickets: state.awayWickets,
      awayOvers: state.awayOvers,
      homeWon: homeWon,
      coinsAwarded: coins,
      xpAwarded: xp,
      playedAt: DateTime.now(),
      batsmanStats: Map.from(state.batsmanStats),
      bowlerStats: Map.from(state.bowlerStats),
      events: List.from(state.events),
    ));

    // Update local user state immediately
    final userNotifier = ref.read(currentUserProvider.notifier);
    userNotifier.updateCoins(coins);
    userNotifier.updateXpAndLevel(xp);

    // Persist to database
    _persistMatchRewards(coins, xp, homeWon == true);
  }

  Future<void> _persistMatchRewards(int coins, int xp, bool won) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.client.rpc('award_match_rewards', params: {
        'p_user_id': userId,
        'p_coins': coins,
        'p_xp': xp,
        'p_won': won,
      });
    } catch (_) {
      // Fallback: direct update if RPC doesn't exist
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) return;
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user == null) return;
        final newXp = user.xp;
        final newLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
        await SupabaseService.client.from('users').update({
          'coins': user.coins,
          'xp': newXp,
          'level': newLevel > AppConstants.maxLevel ? AppConstants.maxLevel : newLevel,
          'matches_played': user.matchesPlayed + 1,
          if (won) 'matches_won': user.matchesWon + 1,
        }).eq('id', userId);
      } catch (_) {}
    }
    // Refresh user data from server
    ref.read(currentUserProvider.notifier).silentRefresh();
  }

  void skipToEnd() {
    _simulationTimer?.cancel();
    if (_engine == null) return;

    final allEvents = <MatchEvent>[...state.events];
    final batsmanStats = Map<String, BatsmanStats>.from(state.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(state.bowlerStats);

    while (true) {
      final result = _engine!.simulateNextBall();
      if (result == null) break;
      allEvents.add(result);

      // Skip stats processing for innings-break synthetic events
      if (result.eventType != 'innings_break') {
        final isExtra = result.eventType == 'wide' || result.eventType == 'no_ball';

        final batKey = '${result.innings}_${result.batsmanCardId}';
        final bowlKey = '${result.innings}_${result.bowlerCardId}';

        final batsmanName = _engine!.getBatsmanName(result.batsmanCardId);
        batsmanStats.putIfAbsent(
            batKey, () => BatsmanStats(name: batsmanName, innings: result.innings));
        final batStats = batsmanStats[batKey]!;
        if (result.eventType != 'wide') batStats.balls++;
        batStats.runs += result.runs;
        if (result.runs == 4) batStats.fours++;
        if (result.runs == 6) batStats.sixes++;
        if (result.isWicket) {
          batStats.isOut = true;
          final bowlerNameForDismissal = _engine!.getBowlerName(result.bowlerCardId);
          final fielderNameForDismissal = result.fielderCardId != null
              ? _engine!.getBatsmanName(result.fielderCardId!)
              : null;
          batStats.dismissalType = _formatDismissal(
            result.wicketType ?? 'bowled',
            bowlerNameForDismissal,
            fielderNameForDismissal,
          );
        }

        final bowlerName = _engine!.getBowlerName(result.bowlerCardId);
        bowlerStats.putIfAbsent(
            bowlKey, () => BowlerStats(name: bowlerName, innings: result.innings));
        final bowlStats = bowlerStats[bowlKey]!;
        if (!isExtra) bowlStats.balls++;
        bowlStats.runs += result.runs;
        if (result.isWicket) bowlStats.wickets++;
        if (result.runs == 0 && !result.isWicket && !isExtra) {
          bowlStats.dotBalls++;
        }
      }
    }

    state = state.copyWith(
      events: allEvents,
      isSimulating: false,
      currentCommentary: _engine!.getMatchResult(),
      currentInnings: allEvents.isNotEmpty ? allEvents.last.innings : state.currentInnings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
    );
    _onMatchComplete();
  }

  void reset() {
    _simulationTimer?.cancel();
    _engine = null;
    state = const MatchState();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

// Match history provider (reads from in-memory notifier)
final matchHistoryProvider = Provider<List<MatchSummary>>((ref) {
  // Access the notifier to get match history
  final notifier = ref.watch(matchProvider.notifier);
  // Re-read when match state changes (so history updates after match completes)
  ref.watch(matchProvider);
  return notifier.matchHistory;
});
