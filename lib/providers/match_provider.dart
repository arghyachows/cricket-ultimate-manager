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
  /// true = home won, false = away won, null = tie or not finished
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;

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
    this.homeWon,
    this.coinsAwarded = 0,
    this.xpAwarded = 0,
  });

  bool get hasActiveMatch => isSimulating || isMatchComplete;

  int get homeScore {
    if (events.isEmpty) return 0;
    final inn1 = events.where((e) => e.innings == 1);
    return inn1.isEmpty ? 0 : inn1.last.scoreAfter;
  }

  int get homeWickets {
    if (events.isEmpty) return 0;
    final inn1 = events.where((e) => e.innings == 1);
    return inn1.isEmpty ? 0 : inn1.last.wicketsAfter;
  }

  int get awayScore {
    if (events.isEmpty) return 0;
    final inn2 = events.where((e) => e.innings == 2);
    return inn2.isEmpty ? 0 : inn2.last.scoreAfter;
  }

  int get awayWickets {
    if (events.isEmpty) return 0;
    final inn2 = events.where((e) => e.innings == 2);
    return inn2.isEmpty ? 0 : inn2.last.wicketsAfter;
  }

  String get currentOvers {
    if (events.isEmpty) return '0.0';
    final last = events.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  String get homeOvers {
    final inn1 = events.where((e) => e.innings == 1);
    if (inn1.isEmpty) return '0.0';
    final last = inn1.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  String get awayOvers {
    final inn2 = events.where((e) => e.innings == 2);
    if (inn2.isEmpty) return '0.0';
    final last = inn2.last;
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
    bool? homeWon,
    int? coinsAwarded,
    int? xpAwarded,
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
      homeWon: homeWon ?? this.homeWon,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      xpAwarded: xpAwarded ?? this.xpAwarded,
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
    String format = 't20',
    String pitchCondition = 'balanced',
  }) async {
    _engine = MatchEngine(
      homeXI: homeXI,
      awayXI: awayXI,
      homeChemistry: homeChemistry,
      awayChemistry: awayChemistry,
      format: format,
      pitchCondition: pitchCondition,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
    );

    state = MatchState(
      isSimulating: true,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      matchFormat: format,
    );

    // Simulate ball by ball with delay for UX
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _simulateNextBall(),
    );
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

    // Use compound key: innings_cardId to separate per-innings stats
    final batKey = '${result.innings}_${result.batsmanCardId}';
    final bowlKey = '${result.innings}_${result.bowlerCardId}';

    // Update batsman stats
    final batsmanName =
        _engine!.getBatsmanName(result.batsmanCardId);
    batsmanStats.putIfAbsent(
        batKey, () => BatsmanStats(name: batsmanName, innings: result.innings));
    final batStats = batsmanStats[batKey]!;
    batStats.balls++;
    batStats.runs += result.runs;
    if (result.runs == 4) batStats.fours++;
    if (result.runs == 6) batStats.sixes++;
    if (result.isWicket) {
      batStats.isOut = true;
      batStats.dismissalType = result.wicketType;
    }

    // Update bowler stats
    final bowlerName = _engine!.getBowlerName(result.bowlerCardId);
    bowlerStats.putIfAbsent(
        bowlKey, () => BowlerStats(name: bowlerName, innings: result.innings));
    final bowlStats = bowlerStats[bowlKey]!;
    bowlStats.balls++;
    bowlStats.runs += result.runs;
    if (result.isWicket) bowlStats.wickets++;
    if (result.runs == 0 && !result.isWicket && result.eventType != 'wide' && result.eventType != 'no_ball') {
      bowlStats.dotBalls++;
    }

    state = state.copyWith(
      events: events,
      currentCommentary: result.commentary,
      currentInnings: result.innings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
    );
  }

  void _onMatchComplete() {
    if (_engine == null) return;

    // Determine winner
    final homeScore = _engine!.score1;
    final awayScore = _engine!.score2;
    bool? homeWon;
    int coins;
    int xp;

    if (homeScore > awayScore) {
      homeWon = true;
      coins = state.matchFormat == 'odi'
          ? AppConstants.matchWinCoins * 2
          : AppConstants.matchWinCoins;
      xp = AppConstants.matchWinXP;
    } else if (awayScore > homeScore) {
      homeWon = false;
      coins = AppConstants.matchLoseCoins;
      xp = AppConstants.matchPlayXP;
    } else {
      homeWon = null;
      coins = AppConstants.matchDrawCoins;
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
        await SupabaseService.client.from('users').update({
          'coins': user.coins,
          'xp': user.xp + xp,
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

      // Update stats for skipped events
      final batKey = '${result.innings}_${result.batsmanCardId}';
      final bowlKey = '${result.innings}_${result.bowlerCardId}';

      final batsmanName = _engine!.getBatsmanName(result.batsmanCardId);
      batsmanStats.putIfAbsent(
          batKey, () => BatsmanStats(name: batsmanName, innings: result.innings));
      final batStats = batsmanStats[batKey]!;
      batStats.balls++;
      batStats.runs += result.runs;
      if (result.runs == 4) batStats.fours++;
      if (result.runs == 6) batStats.sixes++;
      if (result.isWicket) {
        batStats.isOut = true;
        batStats.dismissalType = result.wicketType;
      }

      final bowlerName = _engine!.getBowlerName(result.bowlerCardId);
      bowlerStats.putIfAbsent(
          bowlKey, () => BowlerStats(name: bowlerName, innings: result.innings));
      final bowlStats = bowlerStats[bowlKey]!;
      bowlStats.balls++;
      bowlStats.runs += result.runs;
      if (result.isWicket) bowlStats.wickets++;
      if (result.runs == 0 && !result.isWicket && result.eventType != 'wide' && result.eventType != 'no_ball') {
        bowlStats.dotBalls++;
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
