import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'app_config.dart';

/// Service to interact with Node.js backend for match simulation
class NodeBackendService {
  static String get baseUrl => AppConfig.backendUrl;
  
  static IO.Socket? _socket;
  static bool _isInitialized = false;

  // Broadcast streams for passive subscribers (dashboard banners, etc.)
  static final _ballUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  static final _matchCompleteController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get ballUpdates => _ballUpdateController.stream;
  static Stream<Map<String, dynamic>> get matchCompleteEvents => _matchCompleteController.stream;

  // Handler references for selective event removal
  static Function(dynamic)? _cbBallHandler;
  static Function(dynamic)? _cbCompleteHandler;
  static Function(dynamic)? _cbJoinedHandler;
  static Function(dynamic)? _streamBallHandler;
  static Function(dynamic)? _streamCompleteHandler;

  /// Whether the socket is currently connected
  static bool get isConnected => _socket != null && _socket!.connected;

  /// Initialize Socket.IO connection
  static void initSocket() {
    // If already connected, skip
    if (_socket != null && _socket!.connected) {
      print('🔌 Socket already connected');
      return;
    }

    // Dispose old socket if it exists but isn't connected
    if (_socket != null) {
      print('🔌 Disposing stale socket before reconnecting');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isInitialized = false;
    }

    print('🔌 Initializing Socket.IO connection to $baseUrl');
    
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionAttempts(10)
        .setPath('/socket.io/')
        .setTimeout(20000)
        .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Connected to Node.js backend');
      _isInitialized = true;
    });

    _socket!.onDisconnect((_) {
      print('❌ Disconnected from Node.js backend');
      _isInitialized = false;
    });

    _socket!.onConnectError((error) {
      print('❌ Socket connection error: $error');
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    _socket!.onReconnect((attempt) {
      print('🔄 Reconnected after $attempt attempts');
      _isInitialized = true;
    });

    _socket!.onReconnectError((error) {
      print('❌ Reconnection error: $error');
    });

    _socket!.onReconnectFailed((_) {
      print('❌ Reconnection failed after all attempts');
      _isInitialized = false;
    });

    print('🚀 Attempting to connect...');
    _socket!.connect();
  }

  /// Wait for socket to be connected. Returns true if connected within timeout.
  static Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (_socket != null && _socket!.connected) return true;

    final completer = Completer<bool>();
    Timer? timer;

    void onConnect(_) {
      if (!completer.isCompleted) {
        timer?.cancel();
        completer.complete(true);
      }
    }

    void onError(_) {
      // Don't complete on error — let timeout handle it
      print('⚠️ Socket error while waiting for connection');
    }

    _socket?.once('connect', onConnect);
    _socket?.once('connect_error', onError);

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _socket?.off('connect', onConnect);
        _socket?.off('connect_error', onError);
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Join a match room and listen for updates.
  /// Returns a Future that completes when the room is joined (or fails).
  static Future<bool> joinMatch(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete,
  ) async {
    // Ensure socket is initialized and connected
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected, initializing...');
      initSocket();
      final connected = await waitForConnection();
      if (!connected) {
        print('❌ Socket failed to connect within timeout');
        return false;
      }
    }

    return _joinMatchRoom(matchId, onBallUpdate, onMatchComplete);
  }

  static bool _joinMatchRoom(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete,
  ) {
    if (_socket == null || !_socket!.connected) {
      print('❌ Cannot join room: socket not connected');
      return false;
    }

    // Remove only previous callback-based handlers (preserve stream handlers)
    if (_cbBallHandler != null) _socket!.off('ballUpdate', _cbBallHandler!);
    if (_cbCompleteHandler != null) _socket!.off('matchComplete', _cbCompleteHandler!);
    if (_cbJoinedHandler != null) _socket!.off('joined', _cbJoinedHandler!);

    print('👤 Joining match room: $matchId');
    _socket!.emit('joinMatch', matchId);

    _cbJoinedHandler = (data) {
      print('✅ Joined match room: ${data['matchId']}');
    };
    _socket!.on('joined', _cbJoinedHandler!);

    _cbBallHandler = (data) {
      try {
        final updateData = data as Map<String, dynamic>;
        onBallUpdate(updateData);
        // Feed broadcast stream only if no dedicated stream handler is active
        if (_streamBallHandler == null && !_ballUpdateController.isClosed) {
          _ballUpdateController.add(updateData);
        }
      } catch (e) {
        print('❌ Error processing ball update: $e');
      }
    };
    _socket!.on('ballUpdate', _cbBallHandler!);

    _cbCompleteHandler = (data) {
      try {
        final completeData = data as Map<String, dynamic>;
        onMatchComplete(completeData);
        if (_streamCompleteHandler == null && !_matchCompleteController.isClosed) {
          _matchCompleteController.add(completeData);
        }
      } catch (e) {
        print('❌ Error processing match complete: $e');
      }
    };
    _socket!.on('matchComplete', _cbCompleteHandler!);

    return true;
  }

  /// Leave a match room
  static void leaveMatch(String matchId) {
    if (_socket != null && _socket!.connected) {
      print('👋 Leaving match room: $matchId');
      _socket!.emit('leaveMatch', matchId);
    }
    // Remove only callback-based handlers (preserve stream handlers)
    if (_cbBallHandler != null) {
      _socket?.off('ballUpdate', _cbBallHandler!);
      _cbBallHandler = null;
    }
    if (_cbCompleteHandler != null) {
      _socket?.off('matchComplete', _cbCompleteHandler!);
      _cbCompleteHandler = null;
    }
    if (_cbJoinedHandler != null) {
      _socket?.off('joined', _cbJoinedHandler!);
      _cbJoinedHandler = null;
    }
  }

  /// Subscribe to ball updates for a match room (for dashboard banners).
  /// Uses broadcast streams. Re-joins the room if needed.
  static Future<bool> subscribeToMatchUpdates(String matchId) async {
    if (_socket == null || !_socket!.connected) {
      initSocket();
      final connected = await waitForConnection();
      if (!connected) return false;
    }

    // Join room (server-side join is idempotent if already in room)
    _socket!.emit('joinMatch', matchId);

    // Set up stream-feeding handlers if not already active
    if (_streamBallHandler == null) {
      _streamBallHandler = (data) {
        try {
          if (!_ballUpdateController.isClosed) {
            _ballUpdateController.add(data as Map<String, dynamic>);
          }
        } catch (e) {
          print('❌ Error in stream ball handler: $e');
        }
      };
      _socket!.on('ballUpdate', _streamBallHandler!);
    }

    if (_streamCompleteHandler == null) {
      _streamCompleteHandler = (data) {
        try {
          if (!_matchCompleteController.isClosed) {
            _matchCompleteController.add(data as Map<String, dynamic>);
          }
        } catch (e) {
          print('❌ Error in stream match complete handler: $e');
        }
      };
      _socket!.on('matchComplete', _streamCompleteHandler!);
    }

    return true;
  }

  /// Unsubscribe stream-based match update handlers.
  static void unsubscribeFromMatchUpdates() {
    if (_streamBallHandler != null) {
      _socket?.off('ballUpdate', _streamBallHandler!);
      _streamBallHandler = null;
    }
    if (_streamCompleteHandler != null) {
      _socket?.off('matchComplete', _streamCompleteHandler!);
      _streamCompleteHandler = null;
    }
  }

  /// Start a match simulation
  static Future<bool> startMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    try {
      print('🚀 Node.js: Starting match $matchId');
      print('🌐 Backend URL: $baseUrl/api/match/start');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/match/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'matchId': matchId,
          'config': config,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Node.js response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Node.js success: $data');
        return data['success'] == true;
      }
      
      print('❌ Node.js match start failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e, stackTrace) {
      print('❌ Node.js match start error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop a running match
  static Future<bool> stopMatch(String matchId) async {
    try {
      print('⏹️ Stopping match: $matchId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/match/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'matchId': matchId}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Node.js match stop error: $e');
      return false;
    }
  }

  /// Get current match state
  static Future<Map<String, dynamic>?> getMatchState(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/match/$matchId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('❌ Node.js get match state error: $e');
      return null;
    }
  }

  /// Get list of active matches
  static Future<List<String>> getActiveMatches() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/match/active/list'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['matches'] ?? []);
      }
      
      return [];
    } catch (e) {
      print('❌ Node.js get active matches error: $e');
      return [];
    }
  }

  /// Check backend health
  static Future<bool> checkHealth() async {
    try {
      print('🏋️ Checking backend health at $baseUrl/health');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      print('📊 Health check response: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ Backend is healthy: ${response.body}');
        return true;
      }
      print('❌ Backend health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Node.js health check error: $e');
      return false;
    }
  }

  // ─── Multiplayer match methods (same backend, different route) ──────

  /// Start a multiplayer match simulation
  static Future<bool> startMultiplayerMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    try {
      print('🚀 Node.js: Starting multiplayer match $matchId');
      print('🌐 Backend URL: $baseUrl/api/multiplayer/start');

      final response = await http.post(
        Uri.parse('$baseUrl/api/multiplayer/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'matchId': matchId,
          'config': config,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Node.js multiplayer response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Node.js multiplayer success: $data');
        return data['success'] == true;
      }

      print('❌ Node.js multiplayer start failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e, stackTrace) {
      print('❌ Node.js multiplayer start error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get multiplayer match state
  static Future<Map<String, dynamic>?> getMultiplayerMatchState(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/multiplayer/$matchId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      print('❌ Node.js get multiplayer match state error: $e');
      return null;
    }
  }

  /// Stop a multiplayer match
  static Future<bool> stopMultiplayerMatch(String matchId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/multiplayer/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'matchId': matchId}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Node.js multiplayer stop error: $e');
      return false;
    }
  }

  // ─── Tournament API ───────────────────────────────────────────

  /// Get all active tournaments
  static Future<List<Map<String, dynamic>>> getTournaments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tournament'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['tournaments'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Get tournaments error: $e');
      return [];
    }
  }

  /// Get tournament details with participants and matches
  static Future<Map<String, dynamic>?> getTournamentDetails(String tournamentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tournament/$tournamentId'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Get tournament details error: $e');
      return null;
    }
  }

  /// Get tournament standings
  static Future<List<Map<String, dynamic>>> getTournamentStandings(String tournamentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tournament/$tournamentId/standings'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['standings'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Get standings error: $e');
      return [];
    }
  }

  /// Get match commentary log (from Redis for live, DB for completed)
  static Future<List<Map<String, dynamic>>> getMatchCommentary(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tournament/match/$matchId/commentary'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['commentaryLog'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Get commentary error: $e');
      return [];
    }
  }

  /// Create a tournament
  static Future<Map<String, dynamic>> createTournament({
    required String name,
    String? description,
    String format = 't20',
    int maxParticipants = 8,
    int entryFeeCoins = 0,
    int prizeCoins = 0,
    required String startsAt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tournament/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': description,
          'format': format,
          'maxParticipants': maxParticipants,
          'entryFeeCoins': entryFeeCoins,
          'prizeCoins': prizeCoins,
          'startsAt': startsAt,
        }),
      );
      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200,
        'tournament': data['tournament'],
        'message': data['error'] ?? 'Tournament created',
      };
    } catch (e) {
      print('❌ Create tournament error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Join a tournament
  static Future<Map<String, dynamic>> joinTournament({
    required String tournamentId,
    required String userId,
    required String teamId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tournament/$tournamentId/join'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'teamId': teamId,
        }),
      );
      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['error'] ?? 'Unknown error',
      };
    } catch (e) {
      print('❌ Join tournament error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Check and start a tournament if its start time has passed
  static Future<Map<String, dynamic>> checkStartTournament(String tournamentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tournament/$tournamentId/check-start'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200,
        'status': data['status'] ?? 'unknown',
        'message': data['message'] ?? data['error'] ?? '',
        'matchCount': data['matchCount'] ?? 0,
      };
    } catch (e) {
      print('❌ Check-start tournament error: $e');
      return {'success': false, 'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Get the active tournament match for a user (current live or next scheduled)
  static Future<Map<String, dynamic>?> getTournamentActiveMatch(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tournament/user/$userId/active-match'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Get tournament active match error: $e');
      return null;
    }
  }

  /// Dispose socket connection
  static void dispose() {
    if (_socket != null) {
      print('🔌 Disposing Socket.IO connection');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isInitialized = false;
    }
  }
}
