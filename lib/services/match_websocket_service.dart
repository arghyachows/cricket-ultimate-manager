import 'dart:async';
import '../core/node_backend_service.dart';

/// WebSocket service for real-time match updates.
///
/// This is a thin wrapper around [NodeBackendService] — the single socket
/// owner for the entire app. All Socket.IO init, connect, and event
/// subscriptions funnel through [NodeBackendService] so two connection
/// attempts never race in the same app session.
///
/// Extracted as a separate class for DI/testability so consumers that
/// want an injectable object instead of a static API can use this.
class MatchWebSocketService {
  final void Function(Map<String, dynamic>) onBallUpdate;
  final void Function(Map<String, dynamic>) onMatchComplete;
  final void Function(Map<String, dynamic>) onRoomJoined;

  /// The match/room id this service was last connected to.
  String? _currentMatchId;

  MatchWebSocketService({
    required this.onBallUpdate,
    required this.onMatchComplete,
    required this.onRoomJoined,
  });

  /// Connect to a match room via the shared [NodeBackendService] socket.
  ///
  /// Does NOT create a separate Socket.IO connection — delegates entirely
  /// to the app-wide singleton [NodeBackendService].
  Future<bool> connectToMatch(String matchId, String roomId) async {
    _currentMatchId = matchId;

    // Ensure the shared socket is initialized and connected.
    if (!NodeBackendService.isConnected) {
      NodeBackendService.initSocket();
      final connected = await NodeBackendService.waitForConnection(
        timeout: const Duration(seconds: 10),
      );
      if (!connected) return false;
    }

    // Join the room and wire up callbacks via NodeBackendService's
    // joinMatch (which handles event listener management internally).
    final joined = await NodeBackendService.joinMatch(
      matchId,
      (data) => onBallUpdate(data),
      (data) => onMatchComplete(data),
      onRoomJoined: (data) => onRoomJoined(data),
    );

    return joined;
  }

  /// Disconnect from the match room.
  void disconnect() {
    if (_currentMatchId != null) {
      NodeBackendService.leaveMatch(_currentMatchId!);
      _currentMatchId = null;
    }
  }

  /// Whether the shared socket reports itself as connected.
  bool get isConnected => NodeBackendService.isConnected;
}
