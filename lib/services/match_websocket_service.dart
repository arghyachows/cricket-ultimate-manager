import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/node_backend_service.dart';

/// WebSocket service for real-time match updates.
/// Extracts WebSocket handling from MatchNotifier into a dedicated service.
class MatchWebSocketService {
  final void Function(Map<String, dynamic>) onBallUpdate;
  final void Function(Map<String, dynamic>) onMatchComplete;
  final void Function(Map<String, dynamic>) onRoomJoined;

  IO.Socket? _socket;
  String? _matchId;
  String? _roomId;

  MatchWebSocketService({
    required this.onBallUpdate,
    required this.onMatchComplete,
    required this.onRoomJoined,
  });

  Future<void> connectToMatch(String matchId, String roomId) async {
    _matchId = matchId;
    _roomId = roomId;
    
    _socket = IO.io('${NodeBackendService.baseUrl}', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.on('ball_update', (data) => onBallUpdate(data as Map<String, dynamic>));
    _socket!.on('match_complete', (data) => onMatchComplete(data as Map<String, dynamic>));
    _socket!.on('room_joined', (data) => onRoomJoined(data as Map<String, dynamic>));

    await _socket!.connect();
    _socket!.emit('join_match', {'matchId': matchId, 'roomId': roomId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}
