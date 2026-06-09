import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_service.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'card_packs_provider.dart';
import 'career_stats_provider.dart';
import 'challenge_provider.dart';
import 'match/match_state.dart';
import 'match/match_phase.dart';
export 'match/match_state.dart';
import 'match/match_node_backend.dart';
import 'match/match_local_engine.dart';
import 'match/match_completion_handler.dart';
import 'match_helpers.dart';

final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) {
  return MatchNotifier(ref);
});

class MatchNotifier extends StateNotifier<MatchState> {
  final Ref ref;
  MatchNodeBackend? _nodeBackend;
  MatchLocalEngine? _localEngine;
  bool _matchCompleteFired = false;
  static const bool _nodeBackendEnabled = true;

  final List<MatchSummary> _matchHistory = [];
  List<MatchSummary> get matchHistory => List.unmodifiable(_matchHistory);

  MatchNotifier(this.ref) : super(const MatchState(phase: MatchPhase.notStarted));

  @override
  void dispose() {
    _nodeBackend?.cancel();
    _localEngine?.cancel();
    super.dispose();
  }

  void reset() {
    _nodeBackend?.cancel();
    _localEngine?.cancel();
    _nodeBackend = null;
    _localEngine = null;
    _matchCompleteFired = false;
    state = const MatchState(phase: MatchPhase.notStarted);
  }

  String _playerName(LineupPlayer p) =>
      p.userCard?.playerCard?.playerName ?? 'Unknown';

  // ── Match Start ──

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
    bool challengeMode = false,
  }) async {
    _nodeBackend?.cancel();
    _localEngine?.cancel();
    _matchCompleteFired = false;

    final isHomeBatFirst = homeBatsFirst;
    final userId = SupabaseService.currentUserId;

    // Determine user's XI card IDs for contract consumption
    // User is home team if homeTeamId matches their team, or in single-player (awayTeamId == 'ai')
    final isSinglePlayer = awayTeamId == 'ai';
    final isUserHome = isSinglePlayer || (userId != null && homeTeamId == userId);
    final userXI = isUserHome ? homeXI : awayXI;
    final userXiCardIds = userXI.map((p) => p.userCardId).toList();

    state = MatchState(
      phase: MatchPhase.notStarted,
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
      homeBatsFirst: isHomeBatFirst,
      challengeMode: challengeMode,
      xiOrder1: (isHomeBatFirst ? homeXI : awayXI).map<String>(_playerName).toList(),
      xiOrder2: (isHomeBatFirst ? awayXI : homeXI).map<String>(_playerName).toList(),
      userXiCardIds: userXiCardIds,
    );

    if (_nodeBackendEnabled) {
      print('🎯 PRIMARY: Trying Node.js backend...');
      _nodeBackend = MatchNodeBackend(
        state: state,
        onBallUpdate: _onNodeBallUpdate,
        onMatchComplete: () => _onRemoteMatchComplete(),
      );
      final success = await _nodeBackend!.startMatch(
        homeXI: homeXI,
        awayXI: awayXI,
        homeChemistry: homeChemistry,
        awayChemistry: awayChemistry,
        homeTeamName: homeTeamName,
        awayTeamName: awayTeamName,
        overs: overs,
        pitchCondition: pitchCondition,
        homeBatsFirst: isHomeBatFirst,
      );

      if (success) {
        print('✅ SUCCESS: Using Node.js backend');
        return;
      }
      print('⚠️ FALLBACK: Node.js backend failed, using local engine...');
      _nodeBackend = null;
    }

    _startLocalEngine(
      homeXI: homeXI, awayXI: awayXI,
      homeChemistry: homeChemistry, awayChemistry: awayChemistry,
      homeTeamName: homeTeamName, awayTeamName: awayTeamName,
      overs: overs, pitchCondition: pitchCondition, homeBatsFirst: isHomeBatFirst,
    );
  }

  // ── Node.js Backend Callbacks ──

  void _onNodeBallUpdate(Map<String, dynamic> data) {
    try {
      final result = data['result'] as Map<String, dynamic>?;
      final stateData = data['state'] as Map<String, dynamic>?;
      if (result == null || stateData == null) return;

      final event = MatchEvent(
        id: 'node_${DateTime.now().millisecondsSinceEpoch}',
        matchId: _nodeBackend?.hashCode.toString() ?? '',
        innings: result['innings'] ?? 1,
        overNumber: result['overNumber'] ?? 0,
        ballNumber: result['ballNumber'] ?? 0,
        battingTeamId: '', bowlingTeamId: '',
        batsmanCardId: '', bowlerCardId: '',
        eventType: result['eventType'] ?? 'dot_ball',
        runs: result['runs'] ?? 0,
        commentary: result['commentary'] ?? '',
        scoreAfter: result['scoreAfter'] ?? 0,
        wicketsAfter: result['wicketsAfter'] ?? 0,
      );

      state = state.copyWith(
        events: [...state.events, event],
        currentCommentary: result['commentary'],
        currentInnings: stateData['innings'] ?? 1,
        batsmanStats: MatchHelpers.parseBatsmanStats(stateData['batsmanStats']),
        bowlerStats: MatchHelpers.parseBowlerStats(stateData['bowlerStats']),
        target: stateData['target'] ?? 0,
      );
    } catch (_) {}
  }

  void _onRemoteMatchComplete() {
    _nodeBackend?.cancel();
    _nodeBackend = null;
    state = state.copyWith(isSimulating: false, isMatchComplete: true);
    _onMatchComplete();
  }

  // ── Local Engine ──

  void _startLocalEngine({
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
    _localEngine = MatchLocalEngine(
      onBallSimulated: _onLocalBallSimulated,
      onMatchComplete: _onLocalMatchComplete,
    );
    _localEngine!.start(
      homeXI: homeXI, awayXI: awayXI,
      homeChemistry: homeChemistry, awayChemistry: awayChemistry,
      homeTeamName: homeTeamName, awayTeamName: awayTeamName,
      overs: overs, pitchCondition: pitchCondition, homeBatsFirst: homeBatsFirst,
    );
  }

  void _onLocalBallSimulated() {
    final result = _localEngine?.simulateNextBall();
    if (result == null) return;
    _applyEngineResult(result);
  }

  void _onLocalMatchComplete() {
    final result = _localEngine?.engine?.getMatchResult();
    state = state.copyWith(isSimulating: false, currentCommentary: result);
    _onMatchComplete();
  }

  void _applyEngineResult(MatchEvent result) {
    final engine = _localEngine?.engine;
    if (engine == null) return;
    state = MatchLocalEngine.applyBallResult(state, result, engine);
  }

  void skipToEnd() {
    _localEngine?.cancel();
    final engine = _localEngine?.engine;
    if (engine == null) return;
    state = MatchLocalEngine.computeSkipToEndResult(state, engine);
    _onMatchComplete();
  }

  // ── Match Completion ──

  void _onMatchComplete() {
    if (_matchCompleteFired) return;
    _matchCompleteFired = true;

    final homeTotal = state.homeScore;
    final awayTotal = state.awayScore;
    final rewards = MatchCompletionHandler.calculateRewards(homeTotal, awayTotal, state.matchDifficulty, state.matchOvers);

    state = state.copyWith(
      homeWon: rewards.homeWon,
      coinsAwarded: rewards.coins,
      xpAwarded: rewards.xp,
      isMatchComplete: true,
    );

    MatchCompletionHandler.showNotification(state, rewards.homeWon, rewards.coins, rewards.xp);

    // Save to match history
    _matchHistory.insert(0, MatchSummary(
      homeTeamName: state.homeTeamName, awayTeamName: state.awayTeamName,
      format: state.matchFormat,
      homeScore: state.homeScore, homeWickets: state.homeWickets, homeOvers: state.homeOvers,
      awayScore: state.awayScore, awayWickets: state.awayWickets, awayOvers: state.awayOvers,
      homeWon: rewards.homeWon, coinsAwarded: rewards.coins, xpAwarded: rewards.xp,
      playedAt: DateTime.now(),
      batsmanStats: Map.from(state.batsmanStats), bowlerStats: Map.from(state.bowlerStats),
      events: List.from(state.events), homeBatsFirst: state.homeBatsFirst,
      xiOrder1: state.xiOrder1, xiOrder2: state.xiOrder2,
    ));

    // Persist to DB — local state (coins/XP) only updated on success
    final userId = SupabaseService.currentUserId;
    if (userId != null) {
      // Generate idempotency key for this match completion
      final idempotencyKey = 'match_complete_${state.match?.id ?? DateTime.now().millisecondsSinceEpoch}';
      
      // Consume contracts AFTER simulation but BEFORE reward persistence
      _consumeContractsAndPersistRewards(userId, rewards, state.matchDifficulty, idempotencyKey);
    }

    // Persist career stats
    ref.read(careerStatsNotifierProvider.notifier).persistMatchStats(_matchHistory.first);

    // Challenge mode
    if (state.challengeMode && rewards.homeWon == true) {
      final challengeState = ref.read(challengeProvider);
      if (challengeState.isLoaded && !challengeState.allCompleted) {
        final current = challengeState.currentOpponent;
        if (current != null) {
          Future.microtask(() => ref.read(challengeProvider.notifier).markCurrentAsDefeated(current));
        }
      }
    }
  }

  /// Consume contracts for user's XI, then persist rewards.
  /// Contract consumption happens AFTER match simulation but BEFORE reward persistence.
  Future<void> _consumeContractsAndPersistRewards(
    String userId,
    ({int coins, int xp, bool? homeWon}) rewards,
    String difficulty,
    String idempotencyKey,
  ) async {
    final userXiCardIds = state.userXiCardIds;
    
    if (userXiCardIds.isNotEmpty) {
      final contractResult = await MatchCompletionHandler.consumeContracts(
        userId: userId,
        matchId: state.match?.id ?? '',
        userXiCardIds: userXiCardIds,
        idempotencyKey: idempotencyKey,
      );

      if (!contractResult.success) {
        // Contract consumption failed — surface error but continue to try rewards
        final userNotifier = ref.read(currentUserProvider.notifier);
        userNotifier.setPersistenceError(
          'Failed to consume contracts: ${contractResult.error}',
          pendingCoins: rewards.coins,
          pendingXp: rewards.xp,
          pendingHomeWon: rewards.homeWon,
        );
      } else if (contractResult.totalErrors > 0) {
        // Some players had errors (e.g., already out of contracts)
        print('⚠️ [CONTRACTS] Some contracts could not be consumed: ${contractResult.errors}');
      }
      
      // Refresh user cards to get updated contracts_remaining
      ref.read(userCardsProvider.notifier).refresh();
    }

    // Now persist rewards (after contract consumption)
    await _persistAndApplyRewards(userId, (coins: rewards.coins, xp: rewards.xp, homeWon: rewards.homeWon), difficulty);
  }

  /// Persist rewards to the database. On success, applies local state (coins/XP/level).
  /// On failure, surfaces the error via [currentUserProvider] and stores pending rewards for retry.
  Future<void> _persistAndApplyRewards(String userId, ({int coins, int xp, bool? homeWon}) rewards, String difficulty) async {
    final result = await MatchCompletionHandler.persistRewards(
      userId: userId, coins: rewards.coins, xp: rewards.xp, won: rewards.homeWon, difficulty: difficulty,
    );

    if (!result.success) {
      // Surface error via currentUserProvider so the UI can show a snackbar/retry
      final userNotifier = ref.read(currentUserProvider.notifier);
      userNotifier.setPersistenceError(
        'Failed to save rewards: ${result.error}. Your coins and XP have not been updated.',
        pendingCoins: rewards.coins,
        pendingXp: rewards.xp,
        pendingHomeWon: rewards.homeWon,
        pendingDifficulty: difficulty,
      );
      // Refresh from DB to ensure we show the last known good state
      ref.read(currentUserProvider.notifier).silentRefresh();
      ref.read(userCardPacksProvider.notifier).refresh();
      return;
    }

    // Success — safe to update local state
    final userNotifier = ref.read(currentUserProvider.notifier);
    final oldUser = ref.read(currentUserProvider).valueOrNull;
    final oldLevel = oldUser?.level ?? 1;
    userNotifier.updateCoins(rewards.coins);
    userNotifier.updateXpAndLevel(rewards.xp);
    userNotifier.updateMatchStats(won: rewards.homeWon == true);
    userNotifier.clearPersistenceError();
    final updatedUser = ref.read(currentUserProvider).valueOrNull;
    final newLevel = updatedUser?.level ?? oldLevel;

    if (newLevel > oldLevel) {
      state = state.copyWith(
        levelUpPackAwarded: AppConstants.packNameForLevel(newLevel),
        newLevel: newLevel,
      );
    }

    // Set contract pack awarded if any
    if (result.contractPackAwarded != null && result.contractPackAwarded!.isNotEmpty) {
      state = state.copyWith(
        contractPackAwarded: result.contractPackAwarded,
      );
    }

    ref.read(currentUserProvider.notifier).silentRefresh();
    ref.read(userCardPacksProvider.notifier).refresh();
  }

  /// Retry persisting rewards after a previous failure.
  /// Called by the UI when the user taps "Retry".
  Future<void> retryPersistRewards() async {
    final pending = ref.read(currentUserProvider.notifier).pendingRewards;
    if (pending == null) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    await _persistAndApplyRewards(userId, (coins: pending.coins, xp: pending.xp, homeWon: pending.homeWon), pending.difficulty);
  }

  // ── Helpers ──
}

// Match history provider
final matchHistoryProvider = Provider<List<MatchSummary>>((ref) {
  final notifier = ref.watch(matchProvider.notifier);
  ref.watch(matchProvider);
  return notifier.matchHistory;
});