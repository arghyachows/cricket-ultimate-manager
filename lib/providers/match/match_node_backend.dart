import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/node_backend_service.dart';
import '../../models/models.dart';
import 'match_state.dart';

/// Handles Node.js backend match simulation via Socket.IO.
///
/// This encapsulates: socket connection, room joining, ball-by-ball
/// update processing, polling fallback, and match completion sync.
class MatchNodeBackend {
  final MatchState state;
  final NodeBallUpdateCallback onBallUpdate;
  final NodeMatchCompleteCallback onMatchComplete;

  Timer? _pollingTimer;
  String? _remoteMatchId;

  MatchNodeBackend({
    required this.state,
    required this.onBallUpdate,
    required this.onMatchComplete,
  });

  bool get isActive => _remoteMatchId != null;

  void cancel() {
    _pollingTimer?.cancel();
    if (_remoteMatchId != null) {
      NodeBackendService.leaveMatch(_remoteMatchId!);
    }
    _remoteMatchId = null;
  }

  Future<bool> startMatch({
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
      _remoteMatchId = const Uuid().v4();
      print('📝 Match ID: $_remoteMatchId');

      final homeXIData = homeXI.map((p) => _playerToMap(p)).toList();
      final awayXIData = awayXI.map((p) => _playerToMap(p)).toList();

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

      print('🔌 Connecting Socket.IO before starting match...');
      NodeBackendService.initSocket();
      final connected = await NodeBackendService.waitForConnection(
        timeout: const Duration(seconds: 10),
      );
      if (!connected) {
        print('❌ Socket.IO failed to connect');
        return false;
      }

      print('👤 Joining match room...');
      final joined = await NodeBackendService.joinMatch(
        _remoteMatchId!,
        onBallUpdate,
        (_) => onMatchComplete(),
        onRoomJoined: _onRoomJoined,
      );
      if (!joined) {
        print('❌ Failed to join match room');
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      print('⚙️ Starting match on Node.js backend...');
      final started = await NodeBackendService.startMatch(
        matchId: _remoteMatchId!,
        config: config,
      );

      if (started.success) {
        print('✅ Node.js backend match started successfully!');
        _startPollingFallback();
        return true;
      }

      print('❌ Node.js backend returned false');
      NodeBackendService.leaveMatch(_remoteMatchId!);
      return false;
    } catch (e, stackTrace) {
      print('❌ Node.js backend exception: $e');
      print('  $stackTrace');
      return false;
    }
  }

  Map<String, dynamic> _playerToMap(LineupPlayer p) => {
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
    'isWicketKeeper': p.isWicketKeeper,
    'isBowler1': p.isBowler1,
    'isBowler2': p.isBowler2,
    'isCaptain': p.isCaptain,
    'isViceCaptain': p.isViceCaptain,
  };

  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollCompletion(),
    );
  }

  Future<void> _pollCompletion() async {
    if (_remoteMatchId == null) return;
    try {
      final stateData = await NodeBackendService.getMatchState(_remoteMatchId!);
      if (stateData == null) return;
      final ms = stateData['state'] as Map<String, dynamic>?;
      if (ms == null) return;
      if ((ms['matchComplete'] as bool? ?? false) && (ms['isSimulating'] ?? true)) {
        print('🏁 Match complete detected via completion poll');
        _pollingTimer?.cancel();
        onMatchComplete();
        NodeBackendService.leaveMatch(_remoteMatchId!);
      }
    } catch (_) {}
  }

  void _onRoomJoined(Map<String, dynamic> data) {
    // Room join callback — state sync handled by ball update flow
    print('👤 Node match: Room joined callback received.');
  }
}

typedef NodeBallUpdateCallback = void Function(Map<String, dynamic> data);
typedef NodeMatchCompleteCallback = void Function();