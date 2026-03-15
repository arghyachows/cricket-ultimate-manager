import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/supabase_service.dart';
import '../engine/match_engine.dart';
import '../engine/ai_opponent.dart';
import '../models/models.dart';
import '../providers/match_provider.dart';
import '../providers/auth_provider.dart';

// ─── Local state for multiplayer match ─────────────────────────────────────

class _CommentaryEntry {
  final String commentary;
  final String eventType;
  final int runs;
  final int innings;
  final String oversDisplay;

  const _CommentaryEntry({
    required this.commentary,
    required this.eventType,
    this.runs = 0,
    this.innings = 1,
    this.oversDisplay = '',
  });
}

class _MultiplayerMatchState {
  final bool isLoading;
  final String? error;
  final bool tossComplete;
  final bool tossAnimating;
  final String tossWinner; // 'home' or 'away'
  final String tossDecision; // 'bat' or 'bowl'
  final bool homeBatsFirst;
  final String homeTeamName;
  final String awayTeamName;
  final int matchOvers;
  final String matchFormat;
  final bool isSimulator; // true if this user runs the engine
  final bool isSimulating;
  final bool isMatchComplete;
  final String? currentCommentary;
  final int currentInnings;
  final List<MatchEvent> events;
  final Map<String, BatsmanStats> batsmanStats;
  final Map<String, BowlerStats> bowlerStats;
  final int target;
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;
  final String? matchResult;
  // DB-synced scores for watcher
  final int homeScore;
  final int homeWickets;
  final String homeOvers;
  final int awayScore;
  final int awayWickets;
  final String awayOvers;
  // Watcher commentary log (built from realtime updates)
  final List<_CommentaryEntry> commentaryLog;
  // Watcher player info from DB
  final String homeBatsman;
  final String awayBatsman;
  final String currentBowler;
  final String lastEventType;
  final int lastRuns;

  const _MultiplayerMatchState({
    this.isLoading = true,
    this.error,
    this.tossComplete = false,
    this.tossAnimating = false,
    this.tossWinner = '',
    this.tossDecision = '',
    this.homeBatsFirst = true,
    this.homeTeamName = '',
    this.awayTeamName = '',
    this.matchOvers = 20,
    this.matchFormat = 't20',
    this.isSimulator = false,
    this.isSimulating = false,
    this.isMatchComplete = false,
    this.currentCommentary,
    this.currentInnings = 1,
    this.events = const [],
    this.batsmanStats = const {},
    this.bowlerStats = const {},
    this.target = 0,
    this.homeWon,
    this.coinsAwarded = 0,
    this.xpAwarded = 0,
    this.matchResult,
    this.homeScore = 0,
    this.homeWickets = 0,
    this.homeOvers = '0.0',
    this.awayScore = 0,
    this.awayWickets = 0,
    this.awayOvers = '0.0',
    this.commentaryLog = const [],
    this.homeBatsman = '',
    this.awayBatsman = '',
    this.currentBowler = '',
    this.lastEventType = '',
    this.lastRuns = 0,
  });

  _MultiplayerMatchState copyWith({
    bool? isLoading,
    String? error,
    bool? tossComplete,
    bool? tossAnimating,
    String? tossWinner,
    String? tossDecision,
    bool? homeBatsFirst,
    String? homeTeamName,
    String? awayTeamName,
    int? matchOvers,
    String? matchFormat,
    bool? isSimulator,
    bool? isSimulating,
    bool? isMatchComplete,
    String? currentCommentary,
    int? currentInnings,
    List<MatchEvent>? events,
    Map<String, BatsmanStats>? batsmanStats,
    Map<String, BowlerStats>? bowlerStats,
    int? target,
    bool? homeWon,
    int? coinsAwarded,
    int? xpAwarded,
    String? matchResult,
    int? homeScore,
    int? homeWickets,
    String? homeOvers,
    int? awayScore,
    int? awayWickets,
    String? awayOvers,
    List<_CommentaryEntry>? commentaryLog,
    String? homeBatsman,
    String? awayBatsman,
    String? currentBowler,
    String? lastEventType,
    int? lastRuns,
  }) {
    return _MultiplayerMatchState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      tossComplete: tossComplete ?? this.tossComplete,
      tossAnimating: tossAnimating ?? this.tossAnimating,
      tossWinner: tossWinner ?? this.tossWinner,
      tossDecision: tossDecision ?? this.tossDecision,
      homeBatsFirst: homeBatsFirst ?? this.homeBatsFirst,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      matchOvers: matchOvers ?? this.matchOvers,
      matchFormat: matchFormat ?? this.matchFormat,
      isSimulator: isSimulator ?? this.isSimulator,
      isSimulating: isSimulating ?? this.isSimulating,
      isMatchComplete: isMatchComplete ?? this.isMatchComplete,
      currentCommentary: currentCommentary ?? this.currentCommentary,
      currentInnings: currentInnings ?? this.currentInnings,
      events: events ?? this.events,
      batsmanStats: batsmanStats ?? this.batsmanStats,
      bowlerStats: bowlerStats ?? this.bowlerStats,
      target: target ?? this.target,
      homeWon: homeWon ?? this.homeWon,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      matchResult: matchResult ?? this.matchResult,
      homeScore: homeScore ?? this.homeScore,
      homeWickets: homeWickets ?? this.homeWickets,
      homeOvers: homeOvers ?? this.homeOvers,
      awayScore: awayScore ?? this.awayScore,
      awayWickets: awayWickets ?? this.awayWickets,
      awayOvers: awayOvers ?? this.awayOvers,
      commentaryLog: commentaryLog ?? this.commentaryLog,
      homeBatsman: homeBatsman ?? this.homeBatsman,
      awayBatsman: awayBatsman ?? this.awayBatsman,
      currentBowler: currentBowler ?? this.currentBowler,
      lastEventType: lastEventType ?? this.lastEventType,
      lastRuns: lastRuns ?? this.lastRuns,
    );
  }

  // ─── Computed getters (for simulator who has events) ───────────────

  int _inningsScore(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn && e.eventType != 'innings_break');
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  int _inningsWickets(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn && e.eventType != 'innings_break');
    return inns.isEmpty ? 0 : inns.last.wicketsAfter;
  }

  String _inningsOvers(int inn) {
    final inns = events.where((e) => e.innings == inn && e.eventType != 'innings_break');
    if (inns.isEmpty) return '0.0';
    final last = inns.last;
    return '${last.overNumber}.${last.ballNumber}';
  }

  int get computedHomeScore => isSimulator
      ? (homeBatsFirst ? _inningsScore(1) : _inningsScore(2))
      : homeScore;
  int get computedHomeWickets => isSimulator
      ? (homeBatsFirst ? _inningsWickets(1) : _inningsWickets(2))
      : homeWickets;
  String get computedHomeOvers => isSimulator
      ? (homeBatsFirst ? _inningsOvers(1) : _inningsOvers(2))
      : homeOvers;
  int get computedAwayScore => isSimulator
      ? (homeBatsFirst ? _inningsScore(2) : _inningsScore(1))
      : awayScore;
  int get computedAwayWickets => isSimulator
      ? (homeBatsFirst ? _inningsWickets(2) : _inningsWickets(1))
      : awayWickets;
  String get computedAwayOvers => isSimulator
      ? (homeBatsFirst ? _inningsOvers(2) : _inningsOvers(1))
      : awayOvers;

  List<BatsmanStats> get innings1Batsmen =>
      batsmanStats.values.where((b) => b.innings == 1).toList();
  List<BatsmanStats> get innings2Batsmen =>
      batsmanStats.values.where((b) => b.innings == 2).toList();
  List<BowlerStats> get innings1Bowlers =>
      bowlerStats.values.where((b) => b.innings == 1).toList();
  List<BowlerStats> get innings2Bowlers =>
      bowlerStats.values.where((b) => b.innings == 2).toList();
  List<BatsmanStats> get currentBatsmen =>
      batsmanStats.values
          .where((b) => b.innings == currentInnings && !b.isOut)
          .toList();
  List<BowlerStats> get currentBowlers =>
      bowlerStats.values.where((b) => b.innings == currentInnings).toList();

  int get runsNeeded {
    if (currentInnings < 2 || target == 0) return 0;
    final chasingScore = isSimulator
        ? _inningsScore(2)
        : (homeBatsFirst ? awayScore : homeScore);
    final needed = target + 1 - chasingScore;
    return needed > 0 ? needed : 0;
  }

  int get ballsRemaining {
    if (isSimulator) {
      if (events.isEmpty) return matchOvers * 6;
      final inningsEvents = events.where((e) => e.innings == currentInnings);
      if (inningsEvents.isEmpty) return matchOvers * 6;
      final last = inningsEvents.last;
      final ballsBowled = last.overNumber * 6 + last.ballNumber;
      return (matchOvers * 6) - ballsBowled;
    }
    // Watcher: parse overs display to compute balls
    final chasingOvers = homeBatsFirst ? awayOvers : homeOvers;
    final parts = chasingOvers.split('.');
    final fullOvers = int.tryParse(parts[0]) ?? 0;
    final extraBalls = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final ballsBowled = fullOvers * 6 + extraBalls;
    return (matchOvers * 6) - ballsBowled;
  }

  double get requiredRunRate {
    if (currentInnings < 2 || ballsRemaining <= 0) return 0;
    return (runsNeeded / ballsRemaining) * 6;
  }
}

// ─── Screen Widget ─────────────────────────────────────────────────────────

class MultiplayerMatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  const MultiplayerMatchScreen({super.key, required this.matchId});

  @override
  ConsumerState<MultiplayerMatchScreen> createState() =>
      _MultiplayerMatchScreenState();
}

class _MultiplayerMatchScreenState extends ConsumerState<MultiplayerMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _MultiplayerMatchState _state = const _MultiplayerMatchState();

  MatchEngine? _engine;
  Timer? _simulationTimer;
  StreamSubscription? _realtimeSub;
  final _rng = Random();
  int _homeChemistry = 50;
  int _awayChemistry = 50;

  // Match DB data
  Map<String, dynamic>? _matchData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _simulationTimer?.cancel();
    _realtimeSub?.cancel();
    // Unsubscribe from realtime channel
    SupabaseService.client.channel('mp_match_${widget.matchId}').unsubscribe();
    super.dispose();
  }

  void _setState(_MultiplayerMatchState Function(_MultiplayerMatchState s) fn) {
    if (mounted) setState(() => _state = fn(_state));
  }

  // ─── Load match data from DB ──────────────────────────────────────

  Future<void> _loadMatch() async {
    try {
      final data = await SupabaseService.client
          .from('multiplayer_matches')
          .select()
          .eq('id', widget.matchId)
          .single();

      _matchData = data;
      final userId = SupabaseService.currentUserId;
      final isAway = data['away_user_id'] == userId;

      _setState((s) => s.copyWith(
            isLoading: false,
            homeTeamName: data['home_team_name'] ?? 'Home',
            awayTeamName: data['away_team_name'] ?? 'Away',
            matchOvers: data['match_overs'] ?? 20,
            matchFormat: data['match_format'] ?? 't20',
            isSimulator: isAway, // away user runs the simulation
          ));

      // If match already completed, show result
      if (data['status'] == 'completed') {
        _showCompletedMatch(data);
        return;
      }

      // If match already in progress, resume
      if (data['status'] == 'in_progress') {
        if (isAway) {
          // Simulator: should not happen normally, but handle gracefully
          _setState((s) => s.copyWith(
                tossComplete: true,
                isMatchComplete: true,
                currentCommentary: 'Match already in progress on another device.',
              ));
        } else {
          // Watcher: subscribe to realtime
          _setState((s) => s.copyWith(tossComplete: true));
          _subscribeRealtime();
          _syncFromDb(data);
        }
        return;
      }

      // Match is waiting — do toss
      if (isAway) {
        // Away user (simulator) triggers the toss
        _doToss();
      } else {
        // Home user waits for toss result via realtime
        _subscribeRealtime();
      }
    } catch (e) {
      _setState((s) => s.copyWith(isLoading: false, error: 'Failed to load match: $e'));
    }
  }

  void _showCompletedMatch(Map<String, dynamic> data) {
    final userId = SupabaseService.currentUserId;
    final winnerId = data['winner_user_id'];
    bool? homeWon;
    if (winnerId != null) {
      homeWon = winnerId == data['home_user_id'];
    }
    _setState((s) => s.copyWith(
          isLoading: false,
          tossComplete: true,
          isMatchComplete: true,
          homeScore: data['home_score'] ?? 0,
          homeWickets: data['home_wickets'] ?? 0,
          awayScore: data['away_score'] ?? 0,
          awayWickets: data['away_wickets'] ?? 0,
          matchResult: data['match_result'] ?? 'Match Complete',
          currentCommentary: data['match_result'] ?? 'Match Complete',
          homeWon: homeWon,
          coinsAwarded: userId == winnerId ? 100 : 30,
          xpAwarded: userId == winnerId ? 50 : 20,
        ));
  }

  void _syncFromDb(Map<String, dynamic> data) {
    _setState((s) => s.copyWith(
          homeScore: data['home_score'] ?? 0,
          homeWickets: data['home_wickets'] ?? 0,
          awayScore: data['away_score'] ?? 0,
          awayWickets: data['away_wickets'] ?? 0,
          currentInnings: data['current_innings'] ?? 1,
          currentCommentary: data['current_commentary'] ?? '',
          homeOvers: data['home_overs_display'] ?? '0.0',
          awayOvers: data['away_overs_display'] ?? '0.0',
          target: data['target'] ?? 0,
          isSimulating: data['status'] == 'in_progress',
        ));
  }

  // ─── Toss Logic ───────────────────────────────────────────────────

  Future<void> _doToss() async {
    _setState((s) => s.copyWith(tossAnimating: true));
    await Future.delayed(const Duration(milliseconds: 1500));

    // Random toss
    final homeWinsToss = _rng.nextBool();
    final tossWinner = homeWinsToss ? 'home' : 'away';

    // The toss winner (for simplicity) always chooses to bat
    const decision = 'bat';
    final homeBatsFirst = homeWinsToss;

    _setState((s) => s.copyWith(
          tossAnimating: false,
          tossWinner: tossWinner,
          tossDecision: decision,
          homeBatsFirst: homeBatsFirst,
        ));

    // Update DB with toss result
    try {
      await SupabaseService.client
          .from('multiplayer_matches')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
            'home_score': 0,
            'away_score': 0,
            'home_wickets': 0,
            'away_wickets': 0,
            'current_innings': 1,
            'current_commentary':
                '${_state.homeTeamName} won the toss and chose to bat',
          })
          .eq('id', widget.matchId);
    } catch (_) {}

    // Brief delay to show toss result, then start
    await Future.delayed(const Duration(seconds: 2));
    _setState((s) => s.copyWith(tossComplete: true));

    // Load lineups and start simulation
    await _loadLineupsAndStart();
  }

  // ─── Load Playing XIs and Start Engine ────────────────────────────

  Future<void> _loadLineupsAndStart() async {
    try {
      final homeTeamId = _matchData!['home_team_id'];
      final awayTeamId = _matchData!['away_team_id'];

      // Load both teams with full joins
      List<SquadPlayer> homeXI = [];
      List<SquadPlayer> awayXI = [];

      // Try loading home team
      try {
        final homeResult = await SupabaseService.client
            .from('teams')
            .select('*, squads(*, squad_players(*, user_cards(*, player_cards(*))))')
            .eq('id', homeTeamId)
            .order('position', referencedTable: 'squads.squad_players')
            .single();

        final homeTeam = Team.fromJson(homeResult);
        homeXI = homeTeam.activeSquad?.playingXI ?? [];
        if (homeXI.isEmpty) homeXI = homeTeam.activeSquad?.players ?? [];
        _homeChemistry = homeTeam.chemistry;
      } catch (e) {
        print('Error loading home team: $e');
      }

      // Try loading away team
      try {
        final awayResult = await SupabaseService.client
            .from('teams')
            .select('*, squads(*, squad_players(*, user_cards(*, player_cards(*))))')
            .eq('id', awayTeamId)
            .order('position', referencedTable: 'squads.squad_players')
            .single();

        final awayTeam = Team.fromJson(awayResult);
        awayXI = awayTeam.activeSquad?.playingXI ?? [];
        if (awayXI.isEmpty) awayXI = awayTeam.activeSquad?.players ?? [];
        _awayChemistry = awayTeam.chemistry;
      } catch (e) {
        print('Error loading away team: $e');
      }

      // Fallback: generate AI XI for any team that couldn't be loaded
      // This handles RLS restrictions where one user can't read the other's data
      if (homeXI.isEmpty) {
        print('Home team empty — generating AI fallback XI');
        homeXI = await AIOpponent.generateXI();
      }
      if (awayXI.isEmpty) {
        print('Away team empty — generating AI fallback XI');
        awayXI = await AIOpponent.generateXI();
      }

      // Create engine
      _engine = MatchEngine(
        homeXI: homeXI,
        awayXI: awayXI,
        homeChemistry: _homeChemistry,
        awayChemistry: _awayChemistry,
        overs: _state.matchOvers,
        pitchCondition: 'balanced',
        homeTeamName: _state.homeTeamName,
        awayTeamName: _state.awayTeamName,
        homeBatsFirst: _state.homeBatsFirst,
      );

      _setState((s) => s.copyWith(isSimulating: true));

      // Start ball-by-ball simulation
      _simulationTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => _simulateNextBall(),
      );
    } catch (e) {
      _setState((s) => s.copyWith(error: 'Failed to load lineups: $e'));
    }
  }

  // ─── Ball-by-ball simulation (mirrors match_provider logic) ───────

  void _simulateNextBall() {
    if (_engine == null) return;

    final result = _engine!.simulateNextBall();
    if (result == null) {
      // Match complete
      _simulationTimer?.cancel();
      _onMatchComplete();
      return;
    }

    final events = [..._state.events, result];
    final batsmanStats = Map<String, BatsmanStats>.from(_state.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(_state.bowlerStats);

    if (result.eventType != 'innings_break') {
      final isExtra = result.eventType == 'wide' || result.eventType == 'no_ball';

      final batKey = '${result.innings}_${result.batsmanCardId}';
      final bowlKey = '${result.innings}_${result.bowlerCardId}';

      // Update batsman stats
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

      // Update bowler stats
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

    // Track target when innings changes
    int newTarget = _state.target;
    if (result.innings == 2 && _state.target == 0) {
      // Calculate innings 1 score
      final inn1Events = events.where(
          (e) => e.innings == 1 && e.eventType != 'innings_break');
      if (inn1Events.isNotEmpty) {
        newTarget = inn1Events.last.scoreAfter;
      }
    }

    _setState((s) => s.copyWith(
          events: events,
          currentCommentary: result.commentary,
          currentInnings: result.innings,
          batsmanStats: batsmanStats,
          bowlerStats: bowlerStats,
          target: newTarget,
        ));

    // Push update to DB every ball
    _pushScoreToDb(result);
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

  // ─── Push score to DB (for watcher to see via realtime) ───────────

  Future<void> _pushScoreToDb(MatchEvent event) async {
    final hScore = _state.homeBatsFirst ? _state._inningsScore(1) : _state._inningsScore(2);
    final hWickets = _state.homeBatsFirst ? _state._inningsWickets(1) : _state._inningsWickets(2);
    final aScore = _state.homeBatsFirst ? _state._inningsScore(2) : _state._inningsScore(1);
    final aWickets = _state.homeBatsFirst ? _state._inningsWickets(2) : _state._inningsWickets(1);

    // Get current batsmen/bowler names for watcher display
    String batsmanName = '';
    String bowlerName = '';
    if (_engine != null && event.eventType != 'innings_break') {
      batsmanName = _engine!.getBatsmanName(event.batsmanCardId);
      bowlerName = _engine!.getBowlerName(event.bowlerCardId);
    }

    // Serialize batsman/bowler stats for watcher scorecard
    final scorecardJson = _serializeScorecardData();

    // Build full update with all columns
    final fullUpdate = <String, dynamic>{
      'home_score': hScore,
      'home_wickets': hWickets,
      'away_score': aScore,
      'away_wickets': aWickets,
      'current_innings': event.innings,
      'current_commentary': event.commentary ?? '',
      'home_overs_display': _state.homeBatsFirst
          ? _state._inningsOvers(1)
          : _state._inningsOvers(2),
      'away_overs_display': _state.homeBatsFirst
          ? _state._inningsOvers(2)
          : _state._inningsOvers(1),
      'last_event_type': event.eventType,
      'last_runs': event.runs,
      'target': _state.target,
      'home_batsman': batsmanName,
      'current_bowler': bowlerName,
      'scorecard_data': scorecardJson,
    };

    try {
      await SupabaseService.client
          .from('multiplayer_matches')
          .update(fullUpdate)
          .eq('id', widget.matchId);
    } catch (_) {
      // Extended columns may not exist — fallback to base columns only
      try {
        await SupabaseService.client
            .from('multiplayer_matches')
            .update({
              'home_score': hScore,
              'home_wickets': hWickets,
              'away_score': aScore,
              'away_wickets': aWickets,
            })
            .eq('id', widget.matchId);
      } catch (_) {}
    }
  }

  Map<String, dynamic> _serializeScorecardData() {
    final batsmen = <String, dynamic>{};
    for (final entry in _state.batsmanStats.entries) {
      final b = entry.value;
      batsmen[entry.key] = {
        'name': b.name,
        'innings': b.innings,
        'runs': b.runs,
        'balls': b.balls,
        'fours': b.fours,
        'sixes': b.sixes,
        'isOut': b.isOut,
        'dismissalType': b.dismissalType,
      };
    }
    final bowlers = <String, dynamic>{};
    for (final entry in _state.bowlerStats.entries) {
      final b = entry.value;
      bowlers[entry.key] = {
        'name': b.name,
        'innings': b.innings,
        'balls': b.balls,
        'runs': b.runs,
        'wickets': b.wickets,
        'maidens': b.maidens,
        'dotBalls': b.dotBalls,
      };
    }
    return {'batsmen': batsmen, 'bowlers': bowlers};
  }

  static Map<String, BatsmanStats> _deserializeBatsmanStats(Map<String, dynamic> data) {
    final result = <String, BatsmanStats>{};
    final batsmen = data['batsmen'] as Map<String, dynamic>? ?? {};
    for (final entry in batsmen.entries) {
      final m = entry.value as Map<String, dynamic>;
      result[entry.key] = BatsmanStats(
        name: m['name'] as String? ?? '',
        innings: m['innings'] as int? ?? 1,
        runs: m['runs'] as int? ?? 0,
        balls: m['balls'] as int? ?? 0,
        fours: m['fours'] as int? ?? 0,
        sixes: m['sixes'] as int? ?? 0,
        isOut: m['isOut'] as bool? ?? false,
        dismissalType: m['dismissalType'] as String?,
      );
    }
    return result;
  }

  static Map<String, BowlerStats> _deserializeBowlerStats(Map<String, dynamic> data) {
    final result = <String, BowlerStats>{};
    final bowlers = data['bowlers'] as Map<String, dynamic>? ?? {};
    for (final entry in bowlers.entries) {
      final m = entry.value as Map<String, dynamic>;
      result[entry.key] = BowlerStats(
        name: m['name'] as String? ?? '',
        innings: m['innings'] as int? ?? 1,
        balls: m['balls'] as int? ?? 0,
        runs: m['runs'] as int? ?? 0,
        wickets: m['wickets'] as int? ?? 0,
        maidens: m['maidens'] as int? ?? 0,
        dotBalls: m['dotBalls'] as int? ?? 0,
      );
    }
    return result;
  }

  // ─── Match Complete ───────────────────────────────────────────────

  void _onMatchComplete() {
    if (_engine == null) return;

    final score1 = _engine!.score1;
    final score2 = _engine!.score2;
    final hScore = _state.homeBatsFirst ? score1 : score2;
    final aScore = _state.homeBatsFirst ? score2 : score1;

    bool? homeWon;
    int coins;
    int xp;

    if (hScore > aScore) {
      homeWon = true;
    } else if (aScore > hScore) {
      homeWon = false;
    } else {
      homeWon = null;
    }

    // Determine if current user won
    final userId = SupabaseService.currentUserId;
    final isHome = _matchData?['home_user_id'] == userId;
    final userWon = (isHome && homeWon == true) || (!isHome && homeWon == false);
    final isDraw = homeWon == null;

    if (userWon) {
      coins = 100;
      xp = 50;
    } else if (isDraw) {
      coins = 50;
      xp = 30;
    } else {
      coins = 30;
      xp = 20;
    }

    final resultText = _engine!.getMatchResult();

    _setState((s) => s.copyWith(
          isSimulating: false,
          isMatchComplete: true,
          homeWon: homeWon,
          coinsAwarded: coins,
          xpAwarded: xp,
          currentCommentary: resultText,
          matchResult: resultText,
        ));

    // Update DB with final result
    _pushFinalResult(homeWon, resultText);

    // Award rewards
    _awardRewards(coins, xp, userWon);
  }

  Future<void> _pushFinalResult(bool? homeWon, String resultText) async {
    try {
      final hScore = _state.homeBatsFirst ? _state._inningsScore(1) : _state._inningsScore(2);
      final hWickets = _state.homeBatsFirst ? _state._inningsWickets(1) : _state._inningsWickets(2);
      final aScore = _state.homeBatsFirst ? _state._inningsScore(2) : _state._inningsScore(1);
      final aWickets = _state.homeBatsFirst ? _state._inningsWickets(2) : _state._inningsWickets(1);

      String? winnerId;
      if (homeWon == true) winnerId = _matchData?['home_user_id'];
      if (homeWon == false) winnerId = _matchData?['away_user_id'];

      final update = <String, dynamic>{
        'status': 'completed',
        'home_score': hScore,
        'home_wickets': hWickets,
        'away_score': aScore,
        'away_wickets': aWickets,
        'winner_user_id': winnerId,
        'completed_at': DateTime.now().toIso8601String(),
      };
      try {
        update['match_result'] = resultText;
        update['home_overs_display'] = _state.homeBatsFirst
            ? _state._inningsOvers(1)
            : _state._inningsOvers(2);
        update['away_overs_display'] = _state.homeBatsFirst
            ? _state._inningsOvers(2)
            : _state._inningsOvers(1);
      } catch (_) {}

      await SupabaseService.client
          .from('multiplayer_matches')
          .update(update)
          .eq('id', widget.matchId);
    } catch (_) {}
  }

  Future<void> _awardRewards(int coins, int xp, bool won) async {
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
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) return;
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user == null) return;
        await SupabaseService.client.from('users').update({
          'coins': user.coins + coins,
          'xp': user.xp + xp,
          'matches_played': user.matchesPlayed + 1,
          if (won) 'matches_won': user.matchesWon + 1,
        }).eq('id', userId);
      } catch (_) {}
    }
    // Refresh user data
    ref.read(currentUserProvider.notifier).silentRefresh();
  }

  // ─── Realtime subscription (for watcher / home user) ──────────────

  void _subscribeRealtime() {
    final channel = SupabaseService.client.channel('mp_match_${widget.matchId}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'multiplayer_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.matchId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _onRealtimeUpdate(data);
          },
        )
        .subscribe();
  }

  void _onRealtimeUpdate(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final commentary = data['current_commentary'] as String? ?? '';
    final hScore = data['home_score'] as int? ?? 0;
    final hWickets = data['home_wickets'] as int? ?? 0;
    final aScore = data['away_score'] as int? ?? 0;
    final aWickets = data['away_wickets'] as int? ?? 0;
    final innings = data['current_innings'] as int? ?? 1;
    final hOvers = data['home_overs_display'] as String? ?? '0.0';
    final aOvers = data['away_overs_display'] as String? ?? '0.0';
    final target = data['target'] as int? ?? 0;
    final matchResult = data['match_result'] as String?;
    final eventType = data['last_event_type'] as String? ?? '';
    final lastRuns = data['last_runs'] as int? ?? 0;
    final homeBatsman = data['home_batsman'] as String? ?? '';
    final currentBowler = data['current_bowler'] as String? ?? '';

    // Deserialize scorecard data for watcher
    Map<String, BatsmanStats> watcherBatsmanStats = _state.batsmanStats;
    Map<String, BowlerStats> watcherBowlerStats = _state.bowlerStats;
    final rawScorecard = data['scorecard_data'];
    if (rawScorecard != null && rawScorecard is Map<String, dynamic>) {
      watcherBatsmanStats = _deserializeBatsmanStats(rawScorecard);
      watcherBowlerStats = _deserializeBowlerStats(rawScorecard);
    }

    // Build commentary log entry for the watcher's timeline
    final updatedLog = [..._state.commentaryLog];
    if (commentary.isNotEmpty && commentary != _state.currentCommentary) {
      // Determine overs display based on which team is currently batting
      final currentOvers = innings == 1 ? hOvers : aOvers;
      updatedLog.add(_CommentaryEntry(
        commentary: commentary,
        eventType: eventType,
        runs: lastRuns,
        innings: innings,
        oversDisplay: currentOvers,
      ));
    }

    if (status == 'completed') {
      final winnerId = data['winner_user_id'];
      final userId = SupabaseService.currentUserId;
      bool? homeWon;
      if (winnerId != null) {
        homeWon = winnerId == data['home_user_id'];
      }
      final isHome = data['home_user_id'] == userId;
      final userWon =
          (isHome && homeWon == true) || (!isHome && homeWon == false);
      final isDraw = homeWon == null;

      int coins = userWon ? 100 : (isDraw ? 50 : 30);
      int xp = userWon ? 50 : (isDraw ? 30 : 20);

      _setState((s) => s.copyWith(
            isSimulating: false,
            isMatchComplete: true,
            homeScore: hScore,
            homeWickets: hWickets,
            awayScore: aScore,
            awayWickets: aWickets,
            homeOvers: hOvers,
            awayOvers: aOvers,
            currentInnings: innings,
            currentCommentary: matchResult ?? commentary,
            matchResult: matchResult,
            homeWon: homeWon,
            coinsAwarded: coins,
            xpAwarded: xp,
            target: target,
            commentaryLog: updatedLog,
            homeBatsman: homeBatsman,
            currentBowler: currentBowler,
            batsmanStats: watcherBatsmanStats,
            bowlerStats: watcherBowlerStats,
          ));

      // Award watcher's rewards too
      _awardRewards(coins, xp, userWon);
      return;
    }

    // In progress update
    _setState((s) => s.copyWith(
          tossComplete: true,
          isSimulating: true,
          homeScore: hScore,
          homeWickets: hWickets,
          awayScore: aScore,
          awayWickets: aWickets,
          homeOvers: hOvers,
          awayOvers: aOvers,
          currentInnings: innings,
          currentCommentary: commentary,
          target: target,
          commentaryLog: updatedLog,
          lastEventType: eventType,
          lastRuns: lastRuns,
          homeBatsman: homeBatsman,
          currentBowler: currentBowler,
          batsmanStats: watcherBatsmanStats,
          bowlerStats: watcherBowlerStats,
        ));
  }

  // ─── Skip to End (simulator only) ────────────────────────────────

  void _skipToEnd() {
    _simulationTimer?.cancel();
    if (_engine == null) return;

    final allEvents = <MatchEvent>[..._state.events];
    final batsmanStats = Map<String, BatsmanStats>.from(_state.batsmanStats);
    final bowlerStats = Map<String, BowlerStats>.from(_state.bowlerStats);
    int currentTarget = _state.target;

    while (true) {
      final result = _engine!.simulateNextBall();
      if (result == null) break;
      allEvents.add(result);

      if (result.eventType != 'innings_break') {
        final isExtra =
            result.eventType == 'wide' || result.eventType == 'no_ball';
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
          batStats.dismissalType = _formatDismissal(
            result.wicketType ?? 'bowled',
            _engine!.getBowlerName(result.bowlerCardId),
            result.fielderCardId != null
                ? _engine!.getBatsmanName(result.fielderCardId!)
                : null,
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

      if (result.innings == 2 && currentTarget == 0) {
        final inn1 = allEvents
            .where((e) => e.innings == 1 && e.eventType != 'innings_break');
        if (inn1.isNotEmpty) currentTarget = inn1.last.scoreAfter;
      }
    }

    _setState((s) => s.copyWith(
          events: allEvents,
          batsmanStats: batsmanStats,
          bowlerStats: bowlerStats,
          target: currentTarget,
        ));

    _onMatchComplete();
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_state.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('MULTIPLAYER MATCH')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_state.error != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('MULTIPLAYER MATCH')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                const SizedBox(height: 16),
                Text(_state.error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('BACK'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Toss screen
    if (!_state.tossComplete) {
      return _buildTossScreen();
    }

    // Main match UI (mirrors LiveMatchScreen)
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MULTIPLAYER MATCH'),
        actions: [
          if (_state.isSimulator && _state.isSimulating)
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: 'Skip to end',
              onPressed: _skipToEnd,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'LIVE'),
            Tab(text: 'SCORECARD'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildScoreboard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLiveTab(),
                _buildScorecardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toss Screen ──────────────────────────────────────────────────

  Widget _buildTossScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('TOSS')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coin animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _state.tossAnimating
                      ? [AppTheme.cardGold, AppTheme.cardBronze]
                      : [AppTheme.accent, AppTheme.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: _state.tossAnimating ? 8 : 2,
                  ),
                ],
              ),
              child: Center(
                child: _state.tossAnimating
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        _state.tossWinner.isEmpty
                            ? Icons.monetization_on
                            : Icons.check_circle,
                        color: Colors.white,
                        size: 50,
                      ),
              ),
            ),
            const SizedBox(height: 32),
            if (_state.tossAnimating)
              const Text(
                'Flipping coin...',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              )
            else if (_state.tossWinner.isNotEmpty) ...[
              Text(
                _state.tossWinner == 'home'
                    ? '${_state.homeTeamName} won the toss!'
                    : '${_state.awayTeamName} won the toss!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elected to ${_state.tossDecision}',
                style: const TextStyle(fontSize: 16, color: Colors.white54),
              ),
            ] else if (_state.isSimulator)
              const Text(
                'Tossing coin...',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              )
            else
              const Text(
                'Waiting for toss...',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Scoreboard ───────────────────────────────────────────────────

  Widget _buildScoreboard() {
    final s = _state;
    final homeBatting = s.homeBatsFirst
        ? s.currentInnings == 1
        : s.currentInnings == 2;
    final homeHasBatted =
        s.homeBatsFirst || s.currentInnings >= 2 || s.isMatchComplete;
    final awayHasBatted =
        !s.homeBatsFirst || s.currentInnings >= 2 || s.isMatchComplete;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.6), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Home team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.homeTeamName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: homeBatting ? AppTheme.accent : Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (homeHasBatted)
                      Row(
                        children: [
                          Text(
                            '${s.computedHomeScore}/${s.computedHomeWickets}',
                            style: TextStyle(
                              fontSize: homeBatting ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: homeBatting ? Colors.white : Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${s.computedHomeOvers})',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white38),
                          ),
                        ],
                      )
                    else
                      const Text('Yet to bat',
                          style: TextStyle(fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.currentInnings == 1
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.cardElite.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'INN ${s.currentInnings}',
                      style: TextStyle(
                        color: s.currentInnings == 1
                            ? AppTheme.accent
                            : AppTheme.cardElite,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              // Away team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s.awayTeamName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: !homeBatting ? AppTheme.accent : Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (awayHasBatted) ...[
                          Text(
                            '(${s.computedAwayOvers})',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.computedAwayScore}/${s.computedAwayWickets}',
                            style: TextStyle(
                              fontSize: !homeBatting ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color:
                                  !homeBatting ? Colors.white : Colors.white54,
                            ),
                          ),
                        ] else
                          const Text('Yet to bat',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.isSimulating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
            ),
          // Chase info (both simulator and watcher)
          if (s.currentInnings >= 2 &&
              s.isSimulating &&
              s.runsNeeded > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s.runsNeeded} runs needed from ${s.ballsRemaining} balls  (RRR: ${s.requiredRunRate.toStringAsFixed(2)})',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Live Tab ─────────────────────────────────────────────────────

  Widget _buildLiveTab() {
    final s = _state;
    return Column(
      children: [
        const SizedBox(height: 4),
        // Commentary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.surfaceLight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              s.currentCommentary ?? 'Match starting...',
              key: ValueKey(s.events.length.toString() +
                  s.commentaryLog.length.toString() +
                  (s.currentCommentary ?? '')),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Batsman panel — simulator uses stats, watcher uses DB names
        if (s.isSimulator && s.currentBatsmen.isNotEmpty)
          _buildBatsmanPanel()
        else if (!s.isSimulator && s.homeBatsman.isNotEmpty)
          _buildWatcherBatsmanPanel(),

        // Bowler panel
        if (s.isSimulator && s.currentBowlers.isNotEmpty)
          _buildBowlerPanel()
        else if (!s.isSimulator && s.currentBowler.isNotEmpty)
          _buildWatcherBowlerPanel(),

        // Ball timeline — simulator uses events, watcher uses commentary log
        if (s.isSimulator)
          Expanded(child: _buildTimeline())
        else
          Expanded(child: _buildWatcherTimeline()),

        // Match result
        if (!s.isSimulating && (s.isMatchComplete || s.events.isNotEmpty || s.commentaryLog.isNotEmpty))
          _buildMatchResult(),
      ],
    );
  }

  Widget _buildBatsmanPanel() {
    final activeBatsmen = _state.currentBatsmen.take(2).toList();
    if (activeBatsmen.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surface,
      child: Row(
        children: activeBatsmen.map((b) {
          return Expanded(
            child: Row(
              children: [
                const Icon(Icons.sports_cricket,
                    size: 14, color: AppTheme.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(b.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${b.runs}(${b.balls})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBowlerPanel() {
    final currentBowlers = _state.currentBowlers;
    if (currentBowlers.isEmpty) return const SizedBox();
    final bowler = currentBowlers.last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surfaceLight,
      child: Row(
        children: [
          const Icon(Icons.sports_baseball, size: 14, color: Colors.redAccent),
          const SizedBox(width: 6),
          Text(bowler.name, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            '${bowler.oversDisplay}-${bowler.maidens}-${bowler.runs}-${bowler.wickets}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_state.events.isEmpty) {
      return const Center(
        child: Text('Waiting for match to start...',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _state.events.length,
      itemBuilder: (context, index) {
        final event = _state.events[_state.events.length - 1 - index];
        return _buildEventTile(event);
      },
    );
  }

  Widget _buildEventTile(MatchEvent event) {
    Color eventColor;
    IconData eventIcon;

    switch (event.eventType) {
      case 'four':
        eventColor = AppTheme.primaryLight;
        eventIcon = Icons.looks_4;
        break;
      case 'six':
        eventColor = AppTheme.accent;
        eventIcon = Icons.looks_6;
        break;
      case 'wicket':
        eventColor = AppTheme.error;
        eventIcon = Icons.close;
        break;
      case 'dot_ball':
        eventColor = Colors.white38;
        eventIcon = Icons.fiber_manual_record;
        break;
      case 'wide':
      case 'no_ball':
        eventColor = Colors.orangeAccent;
        eventIcon = Icons.warning_amber;
        break;
      default:
        eventColor = Colors.white54;
        eventIcon = Icons.circle_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: eventColor, width: 3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              event.overDisplay,
              style: TextStyle(
                color: eventColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Icon(eventIcon, size: 16, color: eventColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.commentary ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          if (event.runs > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: eventColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${event.runs}',
                style: TextStyle(
                  color: eventColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Watcher panels (use DB-synced names) ────────────────────────

  Widget _buildWatcherBatsmanPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceLight,
      child: Row(
        children: [
          const Icon(Icons.sports_cricket, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _state.homeBatsman,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const Text(
            'BATTING',
            style: TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildWatcherBowlerPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surface,
      child: Row(
        children: [
          const Icon(Icons.sports_baseball, size: 14, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _state.currentBowler,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
          const Text(
            'BOWLING',
            style: TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ─── Watcher timeline (from commentary log) ─────────────────────

  Widget _buildWatcherTimeline() {
    final log = _state.commentaryLog;
    if (log.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Waiting for ball-by-ball updates...',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: log.length,
      itemBuilder: (context, index) {
        final entry = log[log.length - 1 - index];
        return _buildWatcherEventTile(entry);
      },
    );
  }

  Widget _buildWatcherEventTile(_CommentaryEntry entry) {
    Color eventColor;
    IconData eventIcon;

    switch (entry.eventType) {
      case 'four':
        eventColor = AppTheme.primaryLight;
        eventIcon = Icons.looks_4;
        break;
      case 'six':
        eventColor = AppTheme.accent;
        eventIcon = Icons.looks_6;
        break;
      case 'wicket':
        eventColor = AppTheme.error;
        eventIcon = Icons.close;
        break;
      case 'dot_ball':
        eventColor = Colors.white38;
        eventIcon = Icons.fiber_manual_record;
        break;
      case 'wide':
      case 'no_ball':
        eventColor = Colors.orangeAccent;
        eventIcon = Icons.warning_amber;
        break;
      default:
        eventColor = Colors.white54;
        eventIcon = Icons.circle_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: eventColor, width: 3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              entry.oversDisplay,
              style: TextStyle(
                color: eventColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Icon(eventIcon, size: 16, color: eventColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.commentary,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          if (entry.runs > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: eventColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${entry.runs}',
                style: TextStyle(
                  color: eventColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatchResult() {
    final s = _state;
    final userId = SupabaseService.currentUserId;
    final isHome = _matchData?['home_user_id'] == userId;
    final userWon = (isHome && s.homeWon == true) || (!isHome && s.homeWon == false);
    final isDraw = s.homeWon == null && s.isMatchComplete;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: userWon
              ? [AppTheme.accent.withValues(alpha: 0.3), AppTheme.surface]
              : isDraw
                  ? [Colors.blueAccent.withValues(alpha: 0.2), AppTheme.surface]
                  : [AppTheme.error.withValues(alpha: 0.2), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          Icon(
            userWon
                ? Icons.emoji_events
                : isDraw
                    ? Icons.handshake
                    : Icons.sentiment_dissatisfied,
            color: userWon
                ? AppTheme.accent
                : isDraw
                    ? Colors.blueAccent
                    : Colors.white54,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            userWon ? 'VICTORY!' : isDraw ? 'MATCH DRAWN' : 'DEFEAT',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: userWon
                  ? AppTheme.accent
                  : isDraw
                      ? Colors.blueAccent
                      : Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.currentCommentary ?? 'Match Complete',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Rewards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    color: AppTheme.cardGold, size: 20),
                const SizedBox(width: 6),
                Text(
                  '+${s.coinsAwarded}',
                  style: const TextStyle(
                    color: AppTheme.cardGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.star, color: AppTheme.primaryLight, size: 20),
                const SizedBox(width: 6),
                Text(
                  '+${s.xpAwarded} XP',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: userWon ? AppTheme.accent : null,
              foregroundColor: userWon ? Colors.black : null,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('BACK TO LOBBY'),
          ),
        ],
      ),
    );
  }

  // ─── Scorecard Tab ────────────────────────────────────────────────

  Widget _buildScorecardTab() {
    final s = _state;

    // Watcher without scorecard data yet — show basic scores
    if (!s.isSimulator && s.batsmanStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.scoreboard, color: AppTheme.accent, size: 48),
              const SizedBox(height: 16),
              Text(
                s.isMatchComplete
                    ? 'Final Score'
                    : 'Scorecard loading...',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildBasicScorecard(),
            ],
          ),
        ),
      );
    }

    final battingFirstName =
        s.homeBatsFirst ? s.homeTeamName : s.awayTeamName;
    final battingSecondName =
        s.homeBatsFirst ? s.awayTeamName : s.homeTeamName;
    final inn1Score =
        s.homeBatsFirst ? s.computedHomeScore : s.computedAwayScore;
    final inn1Wickets =
        s.homeBatsFirst ? s.computedHomeWickets : s.computedAwayWickets;
    final inn1Overs =
        s.homeBatsFirst ? s.computedHomeOvers : s.computedAwayOvers;
    final inn2Score =
        s.homeBatsFirst ? s.computedAwayScore : s.computedHomeScore;
    final inn2Wickets =
        s.homeBatsFirst ? s.computedAwayWickets : s.computedHomeWickets;
    final inn2Overs =
        s.homeBatsFirst ? s.computedAwayOvers : s.computedHomeOvers;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (s.innings1Batsmen.isNotEmpty) ...[
          _inningsHeader(
              '$battingFirstName Batting', inn1Score, inn1Wickets, inn1Overs),
          _battingCard(s.innings1Batsmen),
          const SizedBox(height: 4),
          _bowlingCard(s.innings1Bowlers),
        ],
        const SizedBox(height: 16),
        if (s.innings2Batsmen.isNotEmpty) ...[
          _inningsHeader(
              '$battingSecondName Batting', inn2Score, inn2Wickets, inn2Overs),
          _battingCard(s.innings2Batsmen),
          const SizedBox(height: 4),
          _bowlingCard(s.innings2Bowlers),
        ],
        if (s.batsmanStats.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Scorecard will appear once the match starts',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBasicScorecard() {
    final s = _state;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.homeTeamName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${s.homeScore}/${s.homeWickets} (${s.homeOvers})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.awayTeamName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${s.awayScore}/${s.awayWickets} (${s.awayOvers})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inningsHeader(
      String title, int score, int wickets, String overs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.accent)),
          ),
          Text('$score/$wickets ($overs ov)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _battingCard(List<BatsmanStats> batsmen) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Batter',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('R',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('B',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('4s',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('6s',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('SR',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...batsmen.map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color:
                                    b.isOut ? Colors.white54 : Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis),
                          if (b.isOut && b.dismissalType != null)
                            Text(b.dismissalType!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.redAccent))
                          else if (!b.isOut)
                            const Text('not out',
                                style: TextStyle(
                                    fontSize: 10, color: AppTheme.accent)),
                        ],
                      ),
                    ),
                    Expanded(
                        child: Text('${b.runs}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: b.runs >= 50
                                    ? AppTheme.accent
                                    : Colors.white),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.balls}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.fours}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.sixes}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(b.strikeRate.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54),
                            textAlign: TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _bowlingCard(List<BowlerStats> bowlers) {
    if (bowlers.isEmpty) return const SizedBox();

    return Container(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Bowler',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('O',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('M',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('R',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('W',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('ECO',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...bowlers.map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(b.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                        child: Text(b.oversDisplay,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.maidens}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.runs}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.wickets}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: b.wickets >= 3
                                    ? AppTheme.accent
                                    : Colors.white),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(b.economy.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54),
                            textAlign: TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
