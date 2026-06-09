import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/node_backend_service.dart';
import '../../core/supabase_service.dart';
import '../../core/constants.dart';
import 'match_state.dart';

/// A single entry in the ball-by-ball commentary timeline.
class CommentaryEntry {
  final String commentary;
  final String eventType;
  final int runs;
  final int innings;
  final String oversDisplay;

  const CommentaryEntry({
    required this.commentary,
    required this.eventType,
    this.runs = 0,
    this.innings = 1,
    this.oversDisplay = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentaryEntry &&
          runtimeType == other.runtimeType &&
          commentary == other.commentary &&
          eventType == other.eventType &&
          runs == other.runs &&
          innings == other.innings &&
          oversDisplay == other.oversDisplay;

  @override
  int get hashCode => Object.hash(commentary, eventType, runs, innings, oversDisplay);

  @override
  String toString() =>
      'CommentaryEntry(ov:$oversDisplay $eventType "$commentary" +$runs inn$innings)';
}

/// Pure parser for turning raw JSON commentary lists into [CommentaryEntry] lists.
class CommentaryParser {
  /// Parse a list of raw JSON maps (from the backend) into [CommentaryEntry] objects.
  static List<CommentaryEntry> parse(List<dynamic>? rawList) {
    if (rawList == null || rawList.isEmpty) return [];
    final entries = <CommentaryEntry>[];
    for (final entry in rawList) {
      final e = Map<String, dynamic>.from(entry as Map);
      entries.add(CommentaryEntry(
        commentary: e['commentary'] ?? '',
        eventType: e['eventType'] ?? '',
        runs: e['runs'] ?? 0,
        innings: e['innings'] ?? 1,
        oversDisplay: '${e['overNumber'] ?? 0}.${e['ballNumber'] ?? 0}',
      ));
    }
    return entries;
  }
}

/// All mutable state exposed by [MatchSocketManager] for the screen to render.
class TournamentMatchState {
  bool socketConnected = false;
  bool isSimulating = false;
  bool isMatchComplete = false;
  String? error;

  // Team names
  String homeTeamName = 'Home';
  String awayTeamName = 'Away';

  // Toss / homeBatsFirst
  bool homeBatsFirst = true;

  // Scores
  int homeScore = 0;
  int homeWickets = 0;
  String homeOvers = '0.0';
  int awayScore = 0;
  int awayWickets = 0;
  String awayOvers = '0.0';

  // Innings / target
  int currentInnings = 1;
  int target = 0;
  int matchOvers = 20;

  // Commentary & result
  String? currentCommentary;
  String? matchResult;
  final List<CommentaryEntry> commentaryLog = [];

  // Player info
  String homeBatsman = '';
  String awayBatsman = '';
  String currentBowler = '';

  // Scorecard
  Map<String, BatsmanStats> batsmanStats = {};
  Map<String, BowlerStats> bowlerStats = {};

  // Rewards
  int coinsAwarded = 0;
  int xpAwarded = 0;
  String? levelUpPackAwarded;
  String? contractPackAwarded;
  int? newLevel;
}

/// Manages Socket.IO connection, room joining, and match state synchronization
/// for the tournament match screen.
///
/// Owns all mutable tournament match state. The screen reads from [state]
/// and receives notifications via [onStateChanged].
class MatchSocketManager {
  final String matchId;

  /// Called whenever state changes — the screen should [setState] here.
  final VoidCallback onStateChanged;

  /// Called when the match completes (result, raw data provided).
  /// The screen uses this for provider updates and reward persistence.
  final void Function(Map<String, dynamic> data)? onMatchCompleted;

  /// All mutable match state. Screen reads this freely.
  final TournamentMatchState state = TournamentMatchState();

  MatchSocketManager({
    required this.matchId,
    required this.onStateChanged,
    this.onMatchCompleted,
  });

  /// Clean up socket resources.
  void dispose() {
    if (state.socketConnected) {
      NodeBackendService.leaveMatch(matchId);
    }
  }

  /// Fetch match data from Supabase, then connect the socket if live.
  Future<void> loadAndConnect({
    String? homeTeamName,
    String? awayTeamName,
  }) async {
    try {
      final data = await SupabaseService.client
          .from('matches')
          .select(
              '*, home_teams:home_team_id(team_name), away_teams:away_team_id(team_name)')
          .eq('id', matchId)
          .single();

      state.homeTeamName =
          data['home_teams']?['team_name'] ?? homeTeamName ?? 'Home';
      state.awayTeamName =
          data['away_teams']?['team_name'] ?? awayTeamName ?? 'Away';
      final format = data['format'] ?? 't20';
      final oversMap = {'t10': 10, 't20': 20, 'odi': 50, 'test': 90};
      state.matchOvers = oversMap[format] ?? 20;

      if (data['status'] == 'completed') {
        _applyCompletedState(data);
        return;
      }

      state.isSimulating = data['status'] == 'in_progress';
      if (state.isSimulating) {
        state.homeScore = data['home_score'] ?? 0;
        state.homeWickets = data['home_wickets'] ?? 0;
        state.awayScore = data['away_score'] ?? 0;
        state.awayWickets = data['away_wickets'] ?? 0;
      }
      onStateChanged();

      await _connectSocket();
    } catch (e) {
      state.error = 'Failed to load match: $e';
      onStateChanged();
    }
  }

  void _applyCompletedState(Map<String, dynamic> data) {
    state.isMatchComplete = true;
    state.isSimulating = false;
    state.homeScore = data['home_score'] ?? 0;
    state.homeWickets = data['home_wickets'] ?? 0;
    state.homeOvers = (data['home_overs'] ?? 0).toString();
    state.awayScore = data['away_score'] ?? 0;
    state.awayWickets = data['away_wickets'] ?? 0;
    state.awayOvers = (data['away_overs'] ?? 0).toString();
    final winnerId = data['winner_team_id'];
    if (winnerId == data['home_team_id']) {
      state.matchResult = '${state.homeTeamName} won';
    } else if (winnerId == data['away_team_id']) {
      state.matchResult = '${state.awayTeamName} won';
    } else {
      state.matchResult = 'Match Tied';
    }
    onStateChanged();
    _loadCommentary();
  }

  Future<void> _connectSocket() async {
    NodeBackendService.initSocket();
    final connected = await NodeBackendService.waitForConnection(
      timeout: const Duration(seconds: 10),
    );
    if (!connected) return;

    final joined = await NodeBackendService.joinMatch(
      matchId,
      _onBallUpdate,
      _onMatchComplete,
      onRoomJoined: _onRoomJoined,
    );

    if (joined) {
      state.socketConnected = true;
      onStateChanged();
      _loadCommentary();
    }
  }

  void _onRoomJoined(Map<String, dynamic> data) {
    try {
      final stateData = data['state'] as Map<String, dynamic>?;
      if (stateData == null) return;
      applyRoomJoinedState(state, data);
      onStateChanged();
      if (data['state']?['matchComplete'] == true) {
        _onMatchComplete({
          'result': (data['state'] as Map<String, dynamic>?)?['matchResult'] ?? 'Match completed',
          'state': stateData,
        });
      }
    } catch (e) {
      print('❌ Room joined state sync error: $e');
    }
  }

  /// Apply state from a room-joined event to [state].
  /// Syncs all fields: homeBatsFirst, scores, wickets, overs, target,
  /// player names, and scorecard stats.
  @visibleForTesting
  void applyRoomJoinedState(TournamentMatchState state, Map<String, dynamic> data) {
    final s = data['state'] as Map<String, dynamic>? ?? data;

    // homeBatsFirst — critical for correct score mapping
    if (s.containsKey('homeBatsFirst')) {
      state.homeBatsFirst = s['homeBatsFirst'] as bool? ?? state.homeBatsFirst;
    }

    // Innings & target
    state.currentInnings =
        (s['currentInnings'] as int?) ?? (s['innings'] as int?) ?? state.currentInnings;
    state.target = (s['target'] as int?) ?? state.target;

    // Scores (raw values are innings-agnostic; homeBatsFirst maps them)
    final score1 = (s['score1'] as int?) ?? 0;
    final score2 = (s['score2'] as int?) ?? 0;
    final wickets1 = (s['wickets1'] as int?) ?? 0;
    final wickets2 = (s['wickets2'] as int?) ?? 0;
    final hbf = state.homeBatsFirst;
    state.homeScore = hbf ? score1 : score2;
    state.homeWickets = hbf ? wickets1 : wickets2;
    state.awayScore = hbf ? score2 : score1;
    state.awayWickets = hbf ? wickets2 : wickets1;

    // Overs strings
    final ov1 = s['overs1'];
    if (ov1 != null) {
      if (hbf) {
        state.homeOvers = ov1.toString();
      } else {
        state.awayOvers = ov1.toString();
      }
    }
    final ov2 = s['overs2'];
    if (ov2 != null) {
      if (hbf) {
        state.awayOvers = ov2.toString();
      } else {
        state.homeOvers = ov2.toString();
      }
    }

    // Match completion / result
    state.matchResult = s['matchResult'] as String? ?? state.matchResult;
    state.isMatchComplete =
        (s['matchComplete'] as bool?) ?? (s['isMatchComplete'] as bool?) ?? state.isMatchComplete;
    state.isSimulating =
        (s['isSimulating'] as bool?) ?? (!state.isMatchComplete);

    // Player names
    state.homeBatsman = (s['homeBatsman'] as String?) ??
        (s['currentBatsman'] as String?) ??
        state.homeBatsman;
    state.awayBatsman = (s['awayBatsman'] as String?) ??
        (s['currentBatsman2'] as String?) ??
        state.awayBatsman;
    state.currentBowler =
        (s['currentBowler'] as String?) ?? state.currentBowler;

    // Scorecard stats
    final rawBatsmanStats = s['batsmanStats'];
    if (rawBatsmanStats != null) {
      state.batsmanStats =
          _parseBatsmanStats(rawBatsmanStats as Map<String, dynamic>);
    }
    final rawBowlerStats = s['bowlerStats'];
    if (rawBowlerStats != null) {
      state.bowlerStats =
          _parseBowlerStats(rawBowlerStats as Map<String, dynamic>);
    }
  }

  Future<void> _loadCommentary() async {
    try {
      final entries =
          await NodeBackendService.getMatchCommentary(matchId);
      if (entries.isEmpty) return;
      state.commentaryLog
        ..clear()
        ..addAll(CommentaryParser.parse(entries));
      onStateChanged();
    } catch (e) {
      print('⚠️ Failed to load commentary: $e');
    }
  }

  void _onBallUpdate(Map<String, dynamic> data) {
    try {
      final result = data['result'] as Map<String, dynamic>?;
      final stateData = data['state'] as Map<String, dynamic>?;
      if (result == null || stateData == null) return;

      final innings = result['innings'] as int? ?? 1;
      final commentary = result['commentary'] as String? ?? '';
      final eventType = result['eventType'] as String? ?? '';
      final runs = result['runs'] as int? ?? 0;
      final overNumber = result['overNumber'] as int? ?? 0;
      final ballNumber = result['ballNumber'] as int? ?? 0;

      final score1 = stateData['score1'] as int? ?? 0;
      final score2 = stateData['score2'] as int? ?? 0;
      final wickets1 = stateData['wickets1'] as int? ?? 0;
      final wickets2 = stateData['wickets2'] as int? ?? 0;
      final target = stateData['target'] as int? ?? 0;
      final currentBatsmanName = stateData['currentBatsman'] as String? ?? '';
      final currentBowlerName = stateData['currentBowler'] as String? ?? '';

      // homeBatsFirst
      if (stateData.containsKey('homeBatsFirst')) {
        state.homeBatsFirst =
            stateData['homeBatsFirst'] as bool? ?? state.homeBatsFirst;
      }

      final hbf = state.homeBatsFirst;
      state.currentInnings = innings;
      state.target = target;
      state.homeScore = hbf ? score1 : score2;
      state.homeWickets = hbf ? wickets1 : wickets2;
      state.awayScore = hbf ? score2 : score1;
      state.awayWickets = hbf ? wickets2 : wickets1;

      // Overs
      final oversStr =
          ballNumber == 6 ? '${overNumber + 1}.0' : '$overNumber.$ballNumber';
      if (innings == 1) {
        if (hbf) {
          state.homeOvers = oversStr;
        } else {
          state.awayOvers = oversStr;
        }
      } else {
        if (hbf) {
          state.awayOvers = oversStr;
        } else {
          state.homeOvers = oversStr;
        }
      }

      // Player names
      if ((innings == 1 && hbf) || (innings == 2 && !hbf)) {
        state.homeBatsman = currentBatsmanName;
      } else {
        state.awayBatsman = currentBatsmanName;
      }
      state.currentBowler = currentBowlerName;

      // Scorecard
      state.batsmanStats = _parseBatsmanStats(
          stateData['batsmanStats'] as Map<String, dynamic>? ?? {});
      state.bowlerStats = _parseBowlerStats(
          stateData['bowlerStats'] as Map<String, dynamic>? ?? {});

      // Commentary
      if (commentary.isNotEmpty) {
        final currentOvers = (innings == 1)
            ? (hbf ? state.homeOvers : state.awayOvers)
            : (hbf ? state.awayOvers : state.homeOvers);
        state.commentaryLog.add(CommentaryEntry(
          commentary: commentary,
          eventType: eventType,
          runs: runs,
          innings: innings,
          oversDisplay: currentOvers,
        ));
      }

      state.isSimulating = true;
      state.currentCommentary = commentary;
      onStateChanged();
    } catch (e) {
      print('❌ Tournament match ball update error: $e');
    }
  }

  void _onMatchComplete(Map<String, dynamic> data) {
    final result = data['result'] as String? ?? 'Match completed';

    final userWon = result
        .toLowerCase()
        .contains(state.homeTeamName.toLowerCase());
    final isDraw = result.toLowerCase().contains('tie') ||
        result.toLowerCase().contains('draw');
    final coins = userWon
        ? AppConstants.matchWinCoins
        : (isDraw ? AppConstants.matchDrawCoins : AppConstants.matchLoseCoins);
    final xp = userWon ? AppConstants.matchWinXP : AppConstants.matchPlayXP;

    state.coinsAwarded = coins;
    state.xpAwarded = xp;
    state.matchResult = result;
    state.isSimulating = false;
    state.isMatchComplete = true;

    // We need the Ref for providers — but this manager doesn't have one.
    // Instead we expose the data and let the screen handle provider updates.
    // Notify the screen to handle provider updates & reward persistence.
    onStateChanged();
    onMatchCompleted?.call(data);
  }

  // ─── Helpers ────────────────────────────────────────────────────

  Map<String, BatsmanStats> _parseBatsmanStats(
      Map<String, dynamic> data) {
    final result = <String, BatsmanStats>{};
    data.forEach((key, value) {
      final stats = value as Map<String, dynamic>;
      result[key] = BatsmanStats(
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
    return result;
  }

  Map<String, BowlerStats> _parseBowlerStats(
      Map<String, dynamic> data) {
    final result = <String, BowlerStats>{};
    data.forEach((key, value) {
      final stats = value as Map<String, dynamic>;
      result[key] = BowlerStats(
        name: stats['name'] ?? '',
        innings: stats['innings'] ?? 1,
        balls: stats['balls'] ?? 0,
        runs: stats['runs'] ?? 0,
        wickets: stats['wickets'] ?? 0,
        maidens: stats['maidens'] ?? 0,
        dotBalls: stats['dotBalls'] ?? 0,
      );
    });
    return result;
  }
}
