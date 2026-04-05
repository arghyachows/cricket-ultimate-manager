import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Service to interact with Node.js backend for match simulation
class NodeBackendService {
  // Update this URL based on your deployment
  // For Docker: http://127.0.0.1:3000 (use IP, not localhost for web)
  // For production: https://your-domain.com
  static const String baseUrl = 'https://cricket-ultimate-manager-production.up.railway.app';
  
  static IO.Socket? _socket;
  static bool _isInitialized = false;

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

    // Clear any previous listeners
    _socket!.off('ballUpdate');
    _socket!.off('matchComplete');
    _socket!.off('joined');

    print('👤 Joining match room: $matchId');
    _socket!.emit('joinMatch', matchId);

    _socket!.on('joined', (data) {
      print('✅ Joined match room: ${data['matchId']}');
    });

    _socket!.on('ballUpdate', (data) {
      try {
        final updateData = data as Map<String, dynamic>;
        onBallUpdate(updateData);
      } catch (e) {
        print('❌ Error processing ball update: $e');
      }
    });

    _socket!.on('matchComplete', (data) {
      try {
        final completeData = data as Map<String, dynamic>;
        onMatchComplete(completeData);
      } catch (e) {
        print('❌ Error processing match complete: $e');
      }
    });

    return true;
  }

  /// Leave a match room
  static void leaveMatch(String matchId) {
    if (_socket != null && _socket!.connected) {
      print('👋 Leaving match room: $matchId');
      _socket!.emit('leaveMatch', matchId);
    }
    _socket?.off('ballUpdate');
    _socket?.off('matchComplete');
    _socket?.off('joined');
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
