import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'app_config.dart';
import 'logger.dart';
import 'retry_with_backoff.dart';

/// SINGLE socket owner for the entire app.
///
/// ALL Socket.IO init, connect, disconnect, room-join, and event-subscription
/// paths funnel through this class. It owns the single [io.Socket] instance
/// and guarantees:
///
/// 1. **Singleton ownership** — only one socket exists at any time;
///    `MatchWebSocketService` and every screen delegate to this class.
/// 2. **Idempotent init** — `initSocket()` is safe to call many times;
///    concurrent or repeated calls are silently deduplicated.
/// 3. **No stale sockets** — a disconnected / errored socket is always
///    disposed before a new one is created.
/// 4. **Shared connection future** — multiple callers awaiting
///    `waitForConnection()` share the same future; there are never two
///    simultaneous connection timers.
///
/// This class is intentionally all-static — it IS the singleton.
class NodeBackendService {
  static String get baseUrl => AppConfig.backendUrl;
  
  static io.Socket? _socket;

  /// Guards against concurrent connection attempts — only one init at a time.
  static bool _connecting = false;

  /// Shared completer so multiple callers can await the same connection.
  static Completer<bool>? _connectionCompleter;

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

  static String? _currentJoinedMatchId;
  static Function(Map<String, dynamic>)? _onRoomJoinedCallback;

  /// Whether the socket is currently connected
  static bool get isConnected => _socket != null && _socket!.connected;

  /// Initialize the singleton Socket.IO connection.
  ///
  /// **Fully idempotent** — calling this multiple times or from multiple
  /// callers is safe:
  /// - Already connected? → fast-path return, no new socket.
  /// - Connection in progress? → another caller's init is silently ignored.
  /// - Stale (disconnected) socket exists? → disposed before creating a new one.
  ///
  /// The singleton pattern guarantees that only one [io.Socket] is ever
  /// alive at any point in the app's lifetime.
  static void initSocket() {
    // Already connected — fast path
    if (_socket != null && _socket!.connected) {
      Log.d('Socket already connected');
      _registerLifecycleObserver();
      return;
    }

    // Connection already in progress — no redundant init
    if (_connecting) {
      Log.d('Socket connection already in progress, skipping redundant init');
      return;
    }

    _connecting = true;
    _connectionCompleter = Completer<bool>();

    // Dispose stale socket if it exists but isn't connected
    if (_socket != null) {
      Log.d('Disposing stale socket before reconnecting');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _registerLifecycleObserver();
    Log.d('Initializing Socket.IO connection to $baseUrl');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
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
      Log.i('Connected to Node.js backend');
      _connecting = false;
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(true);
        _connectionCompleter = null;
      }
      if (_currentJoinedMatchId != null) {
        Log.d('Re-joining match room on connect: $_currentJoinedMatchId');
        _socket!.emit('joinMatch', _currentJoinedMatchId);
      }
    });

    _socket!.onDisconnect((_) {
      Log.w('Disconnected from Node.js backend');
    });

    _socket!.onConnectError((error) {
      Log.e('Socket connection error', error);
      _connecting = false;
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
        _connectionCompleter = null;
      }
    });

    _socket!.onError((error) {
      Log.e('Socket error', error);
    });

    _socket!.onReconnect((attempt) {
      Log.i('Reconnected after $attempt attempts');
      if (_currentJoinedMatchId != null) {
        Log.d('Re-joining match room on reconnect: $_currentJoinedMatchId');
        _socket!.emit('joinMatch', _currentJoinedMatchId);
      }
    });

    _socket!.onReconnectError((error) {
      Log.e('Reconnection error', error);
    });

    _socket!.onReconnectFailed((_) {
      Log.e('Reconnection failed after all attempts');
    });

    Log.d('Attempting to connect...');
    _socket!.connect();
  }

  /// Wait for socket to be connected. Returns true if connected within timeout.
  /// If already connected, returns immediately with no redundant timers.
  /// If a connection is in progress, shares the same pending future.
  static Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    // Already connected — fast path, no redundant timers
    if (_socket != null && _socket!.connected) return true;

    // Connection in progress — await the shared completer
    if (_connectionCompleter != null) {
      return _connectionCompleter!.future.timeout(timeout, onTimeout: () => false);
    }

    // No connection attempt was started — caller should call initSocket first
    return false;
  }

  /// Join a match room and listen for updates.
  /// Returns a Future that completes when the room is joined (or fails).
  static Future<bool> joinMatch(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete, {
    Function(Map<String, dynamic>)? onRoomJoined,
  }) async {
    // Ensure socket is initialized and connected
    if (_socket == null || !_socket!.connected) {
      Log.w('Socket not connected, initializing...');
      initSocket();
      final connected = await waitForConnection();
      if (!connected) {
        Log.e('Socket failed to connect within timeout');
        return false;
      }
    }

    return _joinMatchRoom(matchId, onBallUpdate, onMatchComplete, onRoomJoined: onRoomJoined);
  }

  static bool _joinMatchRoom(
    String matchId,
    Function(Map<String, dynamic>) onBallUpdate,
    Function(Map<String, dynamic>) onMatchComplete, {
    Function(Map<String, dynamic>)? onRoomJoined,
  }) {
    if (_socket == null || !_socket!.connected) {
      Log.e('Cannot join room: socket not connected');
      return false;
    }

    _currentJoinedMatchId = matchId;
    _onRoomJoinedCallback = onRoomJoined;

    // Remove only previous callback-based handlers (preserve stream handlers)
    if (_cbBallHandler != null) _socket!.off('ballUpdate', _cbBallHandler!);
    if (_cbCompleteHandler != null) _socket!.off('matchComplete', _cbCompleteHandler!);
    if (_cbJoinedHandler != null) _socket!.off('joined', _cbJoinedHandler!);

    Log.i('Joining match room: $matchId');
    _socket!.emit('joinMatch', matchId);

    _cbJoinedHandler = (data) {
      try {
        final joinedData = Map<String, dynamic>.from(data as Map);
        Log.i('Joined match room: ${joinedData['matchId']}');
        if (_onRoomJoinedCallback != null) {
          _onRoomJoinedCallback!(joinedData);
        }
      } catch (e) {
        Log.e('Error in joined handler', e);
      }
    };
    _socket!.on('joined', _cbJoinedHandler!);

    _cbBallHandler = (data) {
      try {
        final updateData = Map<String, dynamic>.from(data as Map);
        onBallUpdate(updateData);
        // Feed broadcast stream only if no dedicated stream handler is active
        if (_streamBallHandler == null && !_ballUpdateController.isClosed) {
          _ballUpdateController.add(updateData);
        }
      } catch (e) {
        Log.e('Error processing ball update', e);
      }
    };
    _socket!.on('ballUpdate', _cbBallHandler!);

    _cbCompleteHandler = (data) {
      try {
        final completeData = Map<String, dynamic>.from(data as Map);
        onMatchComplete(completeData);
        if (_streamCompleteHandler == null && !_matchCompleteController.isClosed) {
          _matchCompleteController.add(completeData);
        }
      } catch (e) {
        Log.e('Error processing match complete', e);
      }
    };
    _socket!.on('matchComplete', _cbCompleteHandler!);

    return true;
  }

  /// Leave a match room
  static void leaveMatch(String matchId) {
    if (_socket != null && _socket!.connected) {
      Log.i('Leaving match room: $matchId');
      _socket!.emit('leaveMatch', matchId);
    }
    _currentJoinedMatchId = null;
    _onRoomJoinedCallback = null;
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
          Log.e('Error in stream ball handler', e);
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
          Log.e('Error in stream match complete handler', e);
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

  /// Start a match simulation with exponential-backoff retry.
  ///
  /// Uses [retryWithBackoff] for full jitter (±25%), configurable timeout,
  /// and structured [RetryResult] error surfacing.
  /// The matchId serves as an idempotency key — the backend deduplicates
  /// start requests with the same matchId.
  static Future<MatchStartResult> startMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    final result = await retryWithBackoff(
      fn: () async {
        Log.i('Node.js: Starting match $matchId');
        Log.d('Backend URL: $baseUrl/api/match/start');

        final response = await http.post(
          Uri.parse('$baseUrl/api/match/start'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'matchId': matchId,
            'config': config,
          }),
        ).timeout(const Duration(seconds: 10));

        Log.d('Node.js response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          Log.i('Node.js success');
          return data['success'] == true;
        }

        // Throw to trigger retry for retryable statuses
        if (isRetryableHttpStatus(response.statusCode)) {
          throw _RetryableHttpException(
            'API returned ${response.statusCode}',
            response.statusCode,
          );
        }

        Log.e('Node.js match start failed: ${response.statusCode}');
        // Non-retryable — return failure, not throw
        return false;
      },
      config: const RetryConfig(
        maxAttempts: 5,
        baseDelayMs: 1000,
        useJitter: true,
      ),
      timeout: const Duration(seconds: 12),
    );

    if (!result.succeeded) {
      if (result.error is _RetryableHttpException) {
        final httpErr = result.error as _RetryableHttpException;
        Log.e('Match start failed after ${result.attemptsUsed} attempts (HTTP ${httpErr.statusCode})');
      } else if (result.error != null) {
        Log.e('Match start failed after ${result.attemptsUsed} attempts', result.error);
      } else {
        Log.e('Match start returned failure after ${result.attemptsUsed} attempts');
      }
    }

    return MatchStartResult(
      success: result.value ?? false,
      attemptsUsed: result.attemptsUsed,
      error: result.error?.toString(),
    );
  }

  /// Stop a running match with exponential-backoff retry.
  static Future<bool> stopMatch(String matchId) async {
    final result = await retryWithBackoff(
      fn: () async {
        Log.d('Stopping match: $matchId');
        
        final response = await http.post(
          Uri.parse('$baseUrl/api/match/stop'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'matchId': matchId}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }

        if (isRetryableHttpStatus(response.statusCode)) {
          throw _RetryableHttpException(
            'API returned ${response.statusCode}',
            response.statusCode,
          );
        }

        Log.e('Node.js match stop failed: ${response.statusCode}');
        return false;
      },
      config: const RetryConfig(
        maxAttempts: 3,
        baseDelayMs: 500,
        useJitter: true,
      ),
      timeout: const Duration(seconds: 15),
    );

    if (!result.succeeded && result.error != null) {
      Log.e('Match stop failed after ${result.attemptsUsed} attempts', result.error);
    }

    return result.value ?? false;
  }

  /// Confirm a match result with idempotency via retryWithBackoff.
  ///
  /// Sends a confirmation to the backend for the given match. The operation
  /// is idempotent — confirming the same match multiple times is safe.
  static Future<bool> confirmMatch(String matchId) async {
    final result = await retryWithBackoff(
      fn: () async {
        Log.i('Confirming match: $matchId');
        
        final response = await http.post(
          Uri.parse('$baseUrl/api/match/confirm'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'matchId': matchId}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }

        if (isRetryableHttpStatus(response.statusCode)) {
          throw _RetryableHttpException(
            'API returned ${response.statusCode}',
            response.statusCode,
          );
        }

        Log.e('Node.js match confirm failed: ${response.statusCode}');
        return false;
      },
      config: const RetryConfig(
        maxAttempts: 3,
        baseDelayMs: 500,
        useJitter: true,
      ),
      timeout: const Duration(seconds: 15),
    );

    if (!result.succeeded && result.error != null) {
      Log.e('Match confirm failed after ${result.attemptsUsed} attempts', result.error);
    }

    return result.value ?? false;
  }

  /// Cancel a running match with idempotency via retryWithBackoff.
  ///
  /// Sends a cancellation request to the backend for the given match.
  /// The operation is idempotent — cancelling an already-cancelled or
  /// completed match returns success without side effects.
  static Future<bool> cancelMatch(String matchId) async {
    final result = await retryWithBackoff(
      fn: () async {
        Log.i('Cancelling match: $matchId');
        
        final response = await http.post(
          Uri.parse('$baseUrl/api/match/cancel'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'matchId': matchId}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }

        if (isRetryableHttpStatus(response.statusCode)) {
          throw _RetryableHttpException(
            'API returned ${response.statusCode}',
            response.statusCode,
          );
        }

        Log.e('Node.js match cancel failed: ${response.statusCode}');
        return false;
      },
      config: const RetryConfig(
        maxAttempts: 3,
        baseDelayMs: 500,
        useJitter: true,
      ),
      timeout: const Duration(seconds: 15),
    );

    if (!result.succeeded && result.error != null) {
      Log.e('Match cancel failed after ${result.attemptsUsed} attempts', result.error);
    }

    return result.value ?? false;
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
      Log.e('Node.js get match state error', e);
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
      Log.e('Node.js get active matches error', e);
      return [];
    }
  }

  /// Check backend health
  static Future<bool> checkHealth() async {
    try {
      Log.d('Checking backend health at $baseUrl/health');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      Log.d('Health check response: ${response.statusCode}');
      if (response.statusCode == 200) {
        Log.i('Backend is healthy');
        return true;
      }
      Log.w('Backend health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      Log.e('Node.js health check error', e);
      return false;
    }
  }

  // ─── Multiplayer match methods (same backend, different route) ──────

  /// Start a multiplayer match with exponential-backoff retry.
  static Future<MatchStartResult> startMultiplayerMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    final result = await retryWithBackoff(
      fn: () async {
        Log.i('Node.js: Starting multiplayer match $matchId');
        Log.d('Backend URL: $baseUrl/api/multiplayer/start');

        final response = await http.post(
          Uri.parse('$baseUrl/api/multiplayer/start'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'matchId': matchId,
            'config': config,
          }),
        ).timeout(const Duration(seconds: 10));

        Log.d('Node.js multiplayer response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          Log.i('Node.js multiplayer success');
          return data['success'] == true;
        }

        if (isRetryableHttpStatus(response.statusCode)) {
          throw _RetryableHttpException(
            'API returned ${response.statusCode}',
            response.statusCode,
          );
        }

        Log.e('Node.js multiplayer start failed: ${response.statusCode}');
        return false;
      },
      config: const RetryConfig(
        maxAttempts: 5,
        baseDelayMs: 1000,
        useJitter: true,
      ),
      timeout: const Duration(seconds: 12),
    );

    if (!result.succeeded && result.error != null) {
      Log.e('Multiplayer match start failed after ${result.attemptsUsed} attempts', result.error);
    }

    return MatchStartResult(
      success: result.value ?? false,
      attemptsUsed: result.attemptsUsed,
      error: result.error?.toString(),
    );
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
      Log.e('Node.js get multiplayer match state error', e);
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
      Log.e('Node.js multiplayer stop error', e);
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
      Log.e('Get tournaments error', e);
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
      Log.e('Get tournament details error', e);
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
      Log.e('Get standings error', e);
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
      Log.e('Get commentary error', e);
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
      Log.e('Create tournament error', e);
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
      Log.e('Join tournament error', e);
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
      Log.e('Check-start tournament error', e);
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
      Log.e('Get tournament active match error', e);
      return null;
    }
  }

  /// Dispose the singleton socket and reset all internal state.
  ///
  /// Safe to call multiple times — second call is a no-op.
  /// After disposal the socket is null, _connecting is false, and any
  /// pending connection completer is cleared. Callers MUST call
  /// initSocket() again before the next connection attempt.
  static void dispose() {
    if (_socket != null) {
      Log.d('Disposing Socket.IO connection');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _connecting = false;
    _connectionCompleter = null;
  }

  static bool _lifecycleObserverRegistered = false;

  static void _registerLifecycleObserver() {
    if (_lifecycleObserverRegistered) return;
    WidgetsBinding.instance.addObserver(_SocketLifecycleObserver());
    _lifecycleObserverRegistered = true;
    Log.d('SocketLifecycleObserver registered successfully');
  }

  static void handleAppResume() {
    if (_socket == null) return;
    Log.d('Reconnect check on App Resume: isConnected=$isConnected, currentJoinedMatchId=$_currentJoinedMatchId');
    
    // Completely reconnect to guarantee fresh connection and trigger room join state sync
    if (_currentJoinedMatchId != null) {
      Log.i('App resumed with active match. Reconnecting socket to guarantee fresh state...');
      _socket!.disconnect();
      _socket!.connect();
    } else if (!_socket!.connected) {
      _socket!.connect();
    }
  }
}

class _SocketLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Log.d('App resumed: Checking Socket.IO connection status...');
      NodeBackendService.handleAppResume();
    }
  }
}

/// Structured result for match start operations.
///
/// Provides more context than a bare bool — caller can inspect
/// how many retry attempts were made and the last error message.
class MatchStartResult {
  final bool success;
  final int attemptsUsed;
  final String? error;

  const MatchStartResult({
    required this.success,
    this.attemptsUsed = 1,
    this.error,
  });
}

/// Internal exception for retryable HTTP status codes.
class _RetryableHttpException implements Exception {
  final String message;
  final int statusCode;
  _RetryableHttpException(this.message, this.statusCode);
  @override
  String toString() => '_RetryableHttpException($statusCode): $message';
}
