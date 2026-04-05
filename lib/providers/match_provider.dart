import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/supabase_service.dart';
import '../core/constants.dart';
import '../core/node_backend_service.dart';
import '../models/models.dart';
import '../engine/match_engine.dart';
import '../core/notification_service.dart';
import 'auth_provider.dart';
import 'card_packs_provider.dart';
import 'career_stats_provider.dart';

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
  final List<String> xiOrder1;
  final List<String> xiOrder2;
  /// Non-null when the user levelled up and earned a card pack this match.
  final String? levelUpPackAwarded;
  final int? newLevel;
  /// Card ID of the batsman on strike (for AT CREASE display).
  final String strikerCardId;
  /// Card ID of the non-striker (for AT CREASE display).
  final String nonStrikerCardId;

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
    this.xiOrder1 = const [],
    this.xiOrder2 = const [],
    this.levelUpPackAwarded,
    this.newLevel,
    this.strikerCardId = '',
    this.nonStrikerCardId = '',
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

  List<BatsmanStats> _orderedBatsmenForInnings(int innings, List<String> xiOrder) {
    final batsmen = batsmanStats.values.where((b) => b.innings == innings).toList();
    if (xiOrder.isEmpty) return batsmen;

    final statsMap = {for (final b in batsmen) b.name: b};
    final ordered = <BatsmanStats>[];

    for (final name in xiOrder) {
      ordered.add(statsMap[name] ?? BatsmanStats(name: name, innings: innings));
    }
    for (final b in batsmen) {
      if (!xiOrder.contains(b.name)) ordered.add(b);
    }
    return ordered;
  }

  /// Batting card for innings 1 (full XI in batting order)
  List<BatsmanStats> get innings1Batsmen => _orderedBatsmenForInnings(1, xiOrder1);

  /// Batting card for innings 2 (full XI in batting order)
  List<BatsmanStats> get innings2Batsmen => _orderedBatsmenForInnings(2, xiOrder2);

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
    if (events.isEmpty) return matchOvers * 6;
    final inningsEvents = events.where((e) => e.innings == currentInnings);
    if (inningsEvents.isEmpty) return matchOvers * 6;
    final last = inningsEvents.last;
    final ballsBowled = last.overNumber * 6 + last.ballNumber;
    return (matchOvers * 6) - ballsBowled;
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
    List<String>? xiOrder1,
    List<String>? xiOrder2,
    String? levelUpPackAwarded,
    int? newLevel,
    String? strikerCardId,
    String? nonStrikerCardId,
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
      xiOrder1: xiOrder1 ?? this.xiOrder1,
      xiOrder2: xiOrder2 ?? this.xiOrder2,
      levelUpPackAwarded: levelUpPackAwarded ?? this.levelUpPackAwarded,
      newLevel: newLevel ?? this.newLevel,
      strikerCardId: strikerCardId ?? this.strikerCardId,
      nonStrikerCardId: nonStrikerCardId ?? this.nonStrikerCardId,
    );
  }
}

class BatsmanStats {
  final String name;
  final int innings;
  final int battingOrder;
  int runs;
  int balls;
  int fours;
  int sixes;
  bool isOut;
  String? dismissalType;

  BatsmanStats({required this.name, required this.innings, this.battingOrder = 99, this.runs = 0, this.balls = 0, this.fours = 0, this.sixes = 0, this.isOut = false, this.dismissalType});

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
  final bool homeBatsFirst;

  final List<String> xiOrder1;
  final List<String> xiOrder2;
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
    this.homeBatsFirst = true,
    this.xiOrder1 = const [],
    this.xiOrder2 = const [],
  });

  /// Team that batted first
  String get battingFirstName => homeBatsFirst ? homeTeamName : awayTeamName;
  /// Team that batted second
  String get battingSecondName => homeBatsFirst ? awayTeamName : homeTeamName;
  /// Innings 1 score (batting-first team)
  int get inn1Score => homeBatsFirst ? homeScore : awayScore;
  int get inn1Wickets => homeBatsFirst ? homeWickets : awayWickets;
  String get inn1Overs => homeBatsFirst ? homeOvers : awayOvers;
  /// Innings 2 score (batting-second team)
  int get inn2Score => homeBatsFirst ? awayScore : homeScore;
  int get inn2Wickets => homeBatsFirst ? awayWickets : homeWickets;
  String get inn2Overs => homeBatsFirst ? awayOvers : homeOvers;

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
  Timer? _pollingTimer;
  MatchEngine? _engine;
  String? _cloudflareMatchId;
  // Always use Node.js backend
  static const bool _nodeBackendEnabled = true;

  MatchNotifier(this.ref) : super(const MatchState());

  static int _inningsScoreFromEvents(List<MatchEvent> events, int inn) {
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  /// In-memory match history
  final List<MatchSummary> _matchHistory = [];
  List<MatchSummary> get matchHistory => List.unmodifiable(_matchHistory);

  Future<void> startMatch({
    required List<LineupPlayer> homeXI,
    required List<LineupPlayer> awayXI,
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
    // Clean up any previous match
    _simulationTimer?.cancel();
    _pollingTimer?.cancel();
    _engine = null;
    _cloudflareMatchId = null;
    
    // Initialize fresh state
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
      xiOrder1: (homeBatsFirst ? homeXI : awayXI)
          .map<String>((p) => p.userCard?.playerCard?.playerName ?? 'Unknown')
          .toList(),
      xiOrder2: (homeBatsFirst ? awayXI : homeXI)
          .map<String>((p) => p.userCard?.playerCard?.playerName ?? 'Unknown')
          .toList(),
    );

    // Try Node.js backend first (retry each match)
    if (_nodeBackendEnabled) {
      print('🎯 PRIMARY: Trying Node.js backend...');
      final success = await _startNodeBackendMatch(
        homeXI: homeXI,
        awayXI: awayXI,
        homeChemistry: homeChemistry,
        awayChemistry: awayChemistry,
        homeTeamName: homeTeamName,
        awayTeamName: awayTeamName,
        overs: overs,
        pitchCondition: pitchCondition,
        homeBatsFirst: homeBatsFirst,
      );

      if (success) {
        print('✅ SUCCESS: Using Node.js backend for match simulation');
        return;
      }

      print('⚠️ FALLBACK: Node.js backend failed, falling back to local engine...');
    }

    // Local engine fallback
    _startLocalMatch(
      homeXI: homeXI,
      awayXI: awayXI,
      homeChemistry: homeChemistry,
      awayChemistry: awayChemistry,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      overs: overs,
      pitchCondition: pitchCondition,
      homeBatsFirst: homeBatsFirst,
    );
  }

  Future<bool> _startNodeBackendMatch({
    required List<LineupPlayer> homeXI,
    required List<LineupPlayer> awayXI,
    required int homeChemistry,
    required int awayChemistry,
    required String homeTeamName,
    required String awayTeamName,
    required int overs,
    required String pitchCondition,
    required bool homeBatsFirst,
  }) async {
    try {
      print('🚀 Attempting Node.js backend match simulation...');
      _cloudflareMatchId = const Uuid().v4();
      print('📝 Match ID: $_cloudflareMatchId');

      // Convert LineupPlayer to simple map format
      final homeXIData = homeXI.map((p) => {
        'userCardId': p.userCardId,
        'name': p.userCard?.playerCard?.playerName ?? 'Unknown',
        'role': p.userCard?.playerCard?.role ?? 'batsman',
        'batting': p.userCard?.effectiveBatting ?? 50,
        'bowling': p.userCard?.effectiveBowling ?? 50,
        'fielding': p.userCard?.playerCard?.fielding ?? 50,
        'aggression': p.userCard?.effectiveBatting ?? 50,
        'technique': p.userCard?.effectiveBatting ?? 50,
        'power': p.userCard?.effectiveBatting ?? 50,
        'consistency': p.userCard?.effectiveBatting ?? 50,
        'pace': p.userCard?.effectiveBowling ?? 50,
        'swing': p.userCard?.effectiveBowling ?? 50,
        'accuracy': p.userCard?.effectiveBowling ?? 50,
        'variations': p.userCard?.effectiveBowling ?? 50,
      }).toList();

      final awayXIData = awayXI.map((p) => {
        'userCardId': p.userCardId,
        'name': p.userCard?.playerCard?.playerName ?? 'Unknown',
        'role': p.userCard?.playerCard?.role ?? 'batsman',
        'batting': p.userCard?.effectiveBatting ?? 50,
        'bowling': p.userCard?.effectiveBowling ?? 50,
        'fielding': p.userCard?.playerCard?.fielding ?? 50,
        'aggression': p.userCard?.effectiveBatting ?? 50,
        'technique': p.userCard?.effectiveBatting ?? 50,
        'power': p.userCard?.effectiveBatting ?? 50,
        'consistency': p.userCard?.effectiveBatting ?? 50,
        'pace': p.userCard?.effectiveBowling ?? 50,
        'swing': p.userCard?.effectiveBowling ?? 50,
        'accuracy': p.userCard?.effectiveBowling ?? 50,
        'variations': p.userCard?.effectiveBowling ?? 50,
      }).toList();

      print('👥 Home XI: ${homeXIData.length} players');
      print('👥 Away XI: ${awayXIData.length} players');

      final config = {
        'homeXI': homeXIData,
        'awayXI': awayXIData,
        'homeChemistry': homeChemistry,
        'awayChemistry': awayChemistry,
        'maxOvers': overs,
        'pitchCondition': pitchCondition,
        'homeTeamName': homeTeamName,
        'awayTeamName': awayTeamName,
        'homeBatsFirst': homeBatsFirst,
        'useAICommentary': false,
      };

      // Step 1: Connect Socket.IO FIRST and wait for connection
      print('🔌 Connecting Socket.IO before starting match...');
      NodeBackendService.initSocket();
      final connected = await NodeBackendService.waitForConnection(
        timeout: const Duration(seconds: 10),
      );

      if (!connected) {
        print('❌ Socket.IO failed to connect — cannot use Node backend');
        return false;
      }

      // Step 2: Join match room and wait for confirmation
      print('👤 Joining match room...');
      final joined = await NodeBackendService.joinMatch(
        _cloudflareMatchId!,
        _onNodeBallUpdate,
        _onNodeMatchComplete,
      );

      if (!joined) {
        print('❌ Failed to join match room');
        return false;
      }

      // Small delay to ensure room join propagates on server
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: NOW start the match (backend starts emitting events)
      print('⚙️ Config prepared, calling Node.js backend...');
      final started = await NodeBackendService.startMatch(
        matchId: _cloudflareMatchId!,
        config: config,
      );

      if (started) {
        print('✅ Node.js backend match started successfully!');
        // Start polling fallback in case Socket.IO events are missed
        _startNodePollingFallback();
        return true;
      }

      print('❌ Node.js backend returned false');
      NodeBackendService.leaveMatch(_cloudflareMatchId!);
      return false;
    } catch (e, stackTrace) {
      print('❌ Node.js backend match start exception: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Polling fallback for Node.js backend matches.
  /// Periodically checks match state via REST API in case Socket.IO events are missed.
  void _startNodePollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollNodeMatchState(),
    );
  }

  Future<void> _pollNodeMatchState() async {
    if (_cloudflareMatchId == null) return;

    try {
      final stateData = await NodeBackendService.getMatchState(_cloudflareMatchId!);
      if (stateData == null) return;

      final matchState = stateData['state'] as Map<String, dynamic>?;
      if (matchState == null) return;

      final isSimulating = stateData['isSimulating'] as bool? ?? false;
      final matchComplete = matchState['matchComplete'] as bool? ?? false;

      // Only use polling data if Socket.IO seems stale (no events for a while)
      // Check by comparing scores — if polling shows higher score, we missed events
      final polledScore1 = matchState['score1'] as int? ?? 0;
      final polledScore2 = matchState['score2'] as int? ?? 0;
      final polledInnings = matchState['innings'] as int? ?? 1;

      // Derive our current score from events
      final currentEvents = state.events;
      final localScore = currentEvents.isNotEmpty ? currentEvents.last.scoreAfter : 0;
      final localInnings = state.currentInnings;

      // If polled state is ahead of our local state, update from polling
      final polledActiveScore = polledInnings == 1 ? polledScore1 : polledScore2;
      if (polledInnings > localInnings || 
          (polledInnings == localInnings && polledActiveScore > localScore)) {
        print('📡 Polling caught up: polled=$polledActiveScore local=$localScore inn=$polledInnings');
        
        // Build a synthetic event from the polled state
        final overNumber = matchState['overNumber'] as int? ?? 0;
        final ballNumber = matchState['ballNumber'] as int? ?? 0;
        final wickets = polledInnings == 1 
            ? (matchState['wickets1'] as int? ?? 0) 
            : (matchState['wickets2'] as int? ?? 0);

        final event = MatchEvent(
          id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
          matchId: _cloudflareMatchId!,
          innings: polledInnings,
          overNumber: overNumber,
          ballNumber: ballNumber,
          battingTeamId: '',
          bowlingTeamId: '',
          batsmanCardId: '',
          bowlerCardId: '',
          eventType: 'dot_ball',
          runs: 0,
          commentary: matchState['currentBatsman'] != null 
              ? '${matchState['currentBatsman']} on strike'
              : '',
          scoreAfter: polledActiveScore,
          wicketsAfter: wickets,
        );

        final events = [...state.events, event];

        // Update batsman/bowler stats from polled state
        final batsmanStatsData = matchState['batsmanStats'] as Map<String, dynamic>? ?? {};
        final batsmanStats = <String, BatsmanStats>{};
        batsmanStatsData.forEach((key, value) {
          final stats = value as Map<String, dynamic>;
          batsmanStats[key] = BatsmanStats(
            name: stats['name'] ?? '',
            innings: stats['innings'] ?? 1,
            battingOrder: stats['battingOrder'] ?? 99,
            runs: stats['runs'] ?? 0,
            balls: stats['balls'] ?? 0,
            fours: stats['fours'] ?? 0,
            sixes: stats['sixes'] ?? 0,
            isOut: stats['isOut'] ?? false,
            dismissalType: stats['dismissalType'],
          );
        });

        final bowlerStatsData = matchState['bowlerStats'] as Map<String, dynamic>? ?? {};
        final bowlerStats = <String, BowlerStats>{};
        bowlerStatsData.forEach((key, value) {
          final stats = value as Map<String, dynamic>;
          bowlerStats[key] = BowlerStats(
            name: stats['name'] ?? '',
            innings: stats['innings'] ?? 1,
            balls: stats['balls'] ?? 0,
            runs: stats['runs'] ?? 0,
            wickets: stats['wickets'] ?? 0,
            maidens: stats['maidens'] ?? 0,
            dotBalls: stats['dotBalls'] ?? 0,
          );
        });

        state = state.copyWith(
          events: events,
          currentInnings: polledInnings,
          batsmanStats: batsmanStats,
          bowlerStats: bowlerStats,
          target: matchState['target'] ?? 0,
        );
      }

      // Handle match complete from polling
      if (matchComplete && state.isSimulating) {
        print('🏁 Match complete detected via polling');
        _pollingTimer?.cancel();
        final matchResult = matchState['matchResult'] as String? ?? 
            'Match completed';
        
        state = state.copyWith(
          isSimulating: false,
          isMatchComplete: true,
          currentCommentary: matchResult,
        );
        
        NodeBackendService.leaveMatch(_cloudflareMatchId!);
        _onMatchComplete();
      }
    } catch (e) {
      // Polling errors are non-fatal
      print('📡 Polling fallback error (non-fatal): $e');
    }
  }

  void _onNodeBallUpdate(Map<String, dynamic> data) {
    try {
      print('⚡ Ball update received from Node.js');
      final result = data['result'] as Map<String, dynamic>?;
      final stateData = data['state'] as Map<String, dynamic>?;
      final commentaryLog = data['commentaryLog'] as List?;

      if (result == null || stateData == null) {
        print('❌ Missing result or state data');
        return;
      }

      print('📝 Commentary: ${result['commentary']}');
      print('📊 Score: ${result['scoreAfter']}/${result['wicketsAfter']}');

      // Build event from result
      final event = MatchEvent(
        id: 'node_${DateTime.now().millisecondsSinceEpoch}',
        matchId: _cloudflareMatchId!,
        innings: result['innings'] ?? 1,
        overNumber: result['overNumber'] ?? 0,
        ballNumber: result['ballNumber'] ?? 0,
        battingTeamId: '',
        bowlingTeamId: '',
        batsmanCardId: '',
        bowlerCardId: '',
        eventType: result['eventType'] ?? 'dot_ball',
        runs: result['runs'] ?? 0,
        commentary: result['commentary'] ?? '',
        scoreAfter: result['scoreAfter'] ?? 0,
        wicketsAfter: result['wicketsAfter'] ?? 0,
      );

      final events = [...state.events, event];
      print('📋 Total events: ${events.length}');

      // Update batsman stats from state
      final batsmanStatsData = stateData['batsmanStats'] as Map<String, dynamic>? ?? {};
      final batsmanStats = <String, BatsmanStats>{};
      
      batsmanStatsData.forEach((key, value) {
        final stats = value as Map<String, dynamic>;
        batsmanStats[key] = BatsmanStats(
          name: stats['name'] ?? '',
          innings: stats['innings'] ?? 1,
          battingOrder: stats['battingOrder'] ?? 99,
          runs: stats['runs'] ?? 0,
          balls: stats['balls'] ?? 0,
          fours: stats['fours'] ?? 0,
          sixes: stats['sixes'] ?? 0,
          isOut: stats['isOut'] ?? false,
          dismissalType: stats['dismissalType'],
        );
      });

      // Update bowler stats from state
      final bowlerStatsData = stateData['bowlerStats'] as Map<String, dynamic>? ?? {};
      final bowlerStats = <String, BowlerStats>{};
      
      bowlerStatsData.forEach((key, value) {
        final stats = value as Map<String, dynamic>;
        bowlerStats[key] = BowlerStats(
          name: stats['name'] ?? '',
          innings: stats['innings'] ?? 1,
          balls: stats['balls'] ?? 0,
          runs: stats['runs'] ?? 0,
          wickets: stats['wickets'] ?? 0,
          maidens: stats['maidens'] ?? 0,
          dotBalls: stats['dotBalls'] ?? 0,
        );
      });

      print('✅ Updating state with new event');
      state = state.copyWith(
        events: events,
        currentCommentary: result['commentary'],
        currentInnings: stateData['innings'] ?? 1,
        batsmanStats: batsmanStats,
        bowlerStats: bowlerStats,
        target: stateData['target'] ?? 0,
      );
      print('✅ State updated successfully');
    } catch (e, stack) {
      print('❌ Error processing Node.js ball update: $e');
      print('Stack trace: $stack');
    }
  }

  void _onNodeMatchComplete(Map<String, dynamic> data) {
    try {
      print('🏁 Match complete received from Node.js');
      _pollingTimer?.cancel();
      final matchResult = data['result'] as String?;
      final stateData = data['state'] as Map<String, dynamic>?;

      if (stateData != null) {
        // Update final state
        final batsmanStatsData = stateData['batsmanStats'] as Map<String, dynamic>? ?? {};
        final batsmanStats = <String, BatsmanStats>{};
        
        batsmanStatsData.forEach((key, value) {
          final stats = value as Map<String, dynamic>;
          batsmanStats[key] = BatsmanStats(
            name: stats['name'] ?? '',
            innings: stats['innings'] ?? 1,
            battingOrder: stats['battingOrder'] ?? 99,
            runs: stats['runs'] ?? 0,
            balls: stats['balls'] ?? 0,
            fours: stats['fours'] ?? 0,
            sixes: stats['sixes'] ?? 0,
            isOut: stats['isOut'] ?? false,
            dismissalType: stats['dismissalType'],
          );
        });

        final bowlerStatsData = stateData['bowlerStats'] as Map<String, dynamic>? ?? {};
        final bowlerStats = <String, BowlerStats>{};
        
        bowlerStatsData.forEach((key, value) {
          final stats = value as Map<String, dynamic>;
          bowlerStats[key] = BowlerStats(
            name: stats['name'] ?? '',
            innings: stats['innings'] ?? 1,
            balls: stats['balls'] ?? 0,
            runs: stats['runs'] ?? 0,
            wickets: stats['wickets'] ?? 0,
            maidens: stats['maidens'] ?? 0,
            dotBalls: stats['dotBalls'] ?? 0,
          );
        });

        state = state.copyWith(
          batsmanStats: batsmanStats,
          bowlerStats: bowlerStats,
          currentCommentary: matchResult,
          isSimulating: false,
          isMatchComplete: true,
        );
      }

      // Leave WebSocket room
      NodeBackendService.leaveMatch(_cloudflareMatchId!);

      // Trigger match completion logic
      _onMatchComplete();
    } catch (e) {
      print('❌ Error processing Node.js match complete: $e');
    }
  }

  void _startLocalMatch({
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

    // Simulate ball by ball with delay for UX
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
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

      // Ensure both current batsmen (striker + non-striker) have stats entries
      final sId = _engine!.currentStrikerCardId;
      final nsId = _engine!.currentNonStrikerCardId;
      if (sId != null) {
        final sKey = '${result.innings}_$sId';
        final sName = _engine!.getBatsmanName(sId);
        batsmanStats.putIfAbsent(sKey, () => BatsmanStats(name: sName, innings: result.innings));
      }
      if (nsId != null) {
        final nsKey = '${result.innings}_$nsId';
        final nsName = _engine!.getBatsmanName(nsId);
        batsmanStats.putIfAbsent(nsKey, () => BatsmanStats(name: nsName, innings: result.innings));
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

    // Track which batsmen are currently at the crease
    final newStrikerId = result.eventType != 'innings_break'
        ? (_engine!.currentStrikerCardId ?? '')
        : '';
    final newNonStrikerId = result.eventType != 'innings_break'
        ? (_engine!.currentNonStrikerCardId ?? '')
        : '';

    state = state.copyWith(
      events: events,
      currentCommentary: result.commentary,
      currentInnings: result.innings,
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
      target: newTarget,
      strikerCardId: newStrikerId,
      nonStrikerCardId: newNonStrikerId,
    );
  }

  void _onMatchComplete() {
    // For Cloudflare matches, we need to get scores from state, not engine
    final score1 = state.homeBatsFirst ? state.homeScore : state.awayScore;
    final score2 = state.homeBatsFirst ? state.awayScore : state.homeScore;
    final homeBatsFirst = state.homeBatsFirst;

    // Home score depends on batting order
    final homeTotal = state.homeScore;
    final awayTotal = state.awayScore;

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

    // Send local notification
    final resultLabel = homeWon == true
        ? 'Victory!'
        : homeWon == false
            ? 'Defeat'
            : 'Draw';
    NotificationService.instance.showMatchResult(
      title: 'Quick Match $resultLabel',
      body:
          '${state.homeTeamName} ${state.homeScore}/${state.homeWickets} vs ${state.awayTeamName} ${state.awayScore}/${state.awayWickets} — +$coins coins, +$xp XP',
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
      homeBatsFirst: state.homeBatsFirst,
      xiOrder1: state.xiOrder1,
      xiOrder2: state.xiOrder2,
    ));

    // Update local user state immediately
    final userNotifier = ref.read(currentUserProvider.notifier);
    final oldUser = ref.read(currentUserProvider).valueOrNull;
    final oldLevel = oldUser?.level ?? 1;
    userNotifier.updateCoins(coins);
    userNotifier.updateXpAndLevel(xp);
    final updatedUser = ref.read(currentUserProvider).valueOrNull;
    final newLevel = updatedUser?.level ?? oldLevel;

    // Detect level-up → pack reward
    if (newLevel > oldLevel) {
      final packName = AppConstants.packNameForLevel(newLevel);
      state = state.copyWith(
        levelUpPackAwarded: packName,
        newLevel: newLevel,
      );
    }

    // Persist to database (also grants pack server-side on level-up)
    _persistMatchRewards(coins, xp, homeWon == true);

    // Persist player career stats
    ref.read(careerStatsNotifierProvider.notifier).persistMatchStats(_matchHistory.first);
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
    // Refresh card packs so new level-up pack appears
    ref.read(userCardPacksProvider.notifier).refresh();
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
    _pollingTimer?.cancel();
    if (_cloudflareMatchId != null && _nodeBackendEnabled) {
      NodeBackendService.leaveMatch(_cloudflareMatchId!);
    }
    _engine = null;
    _cloudflareMatchId = null;
    state = const MatchState();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pollingTimer?.cancel();
    if (_cloudflareMatchId != null && _nodeBackendEnabled) {
      NodeBackendService.leaveMatch(_cloudflareMatchId!);
    }
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
