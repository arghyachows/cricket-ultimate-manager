import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Service to interact with Node.js backend for match simulation
class NodeBackendService {
  // Update this URL based on your deployment
  // For Docker: http://127.0.0.1:3000 (use IP, not localhost for web)
  // For production: https://your-domain.com
  static const String baseUrl = 'http://127.0.0.1:3000';
  
  static IO.Socket? _socket;
  static bool _isInitialized = false;

  /// Initialize Socket.IO connection
  static void initSocket() {
    if (_isInitialized) {
      print('🔌 Socket already initialized');
      return;
    }

    print('🔌 Initializing Socket.IO connection to $baseUrl');
    
    _socket = IO.io(
      baseUrl,
      <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 5,
      },
    );

    _socket!.connect();

    _socket!.on('connect', (_) {
      print('✅ Connected to Node.js backend');
      _isInitialized = true;
    });

    _socket!.on('disconnect', (_) {
      print('❌ Disconnected from Node.js backend');
      _isInitialized = false;
    });

    _socket!.on('connect_error', (error) {
      print('❌ Socket connection error: $error');
    });

    _socket!.on('error', (error) {
      print('❌ Socket error: $error');
    });
  }

  /// Join a match room to receive real-time updates
  static void joinMatch(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete,
  ) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Socket not connected, initializing...');
      initSocket();
      
      // Wait for connection
      _socket!.once('connect', (_) {
        _joinMatchRoom(matchId, onBallUpdate, onMatchComplete);
      });
    } else {
      _joinMatchRoom(matchId, onBallUpdate, onMatchComplete);
    }
  }

  static void _joinMatchRoom(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete,
  ) {
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
  }

  /// Leave a match room
  static void leaveMatch(String matchId) {
    if (_socket != null && _socket!.connected) {
      print('👋 Leaving match room: $matchId');
      _socket!.emit('leaveMatch', matchId);
      _socket!.off('ballUpdate');
      _socket!.off('matchComplete');
      _socket!.off('joined');
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
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
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
