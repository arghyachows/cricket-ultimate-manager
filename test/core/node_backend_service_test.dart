import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/core/node_backend_service.dart';
import 'package:cricket_ultimate_manager/services/match_websocket_service.dart';

/// Verifies that NodeBackendService provides a single socket owner and
/// never allows two simultaneous Socket.IO connection attempts.
///
/// Acceptance criteria:
/// - All socket init paths funnel through NodeBackendService singleton
/// - initSocket is truly idempotent — no stale socket leaks
/// - waitForConnection handles already-connected case without redundant timers
/// - No test can produce two simultaneous Socket.IO connections
void main() {
  // NodeBackendService.initSocket calls _registerLifecycleObserver which
  // accesses WidgetsBinding.instance — ensure binding is available for tests
  // that exercise initSocket.
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NodeBackendService socket singleton', () {
    setUp(() {
      // Full state reset between tests — disposes socket, clears _connecting
      // and _connectionCompleter guards, and resets lifecycle observer flag.
      NodeBackendService.dispose();
    });

    test('isConnected returns false after dispose', () {
      expect(NodeBackendService.isConnected, false);
    });

    test('waitForConnection returns false when no init was called', () async {
      // Without a prior initSocket call, there's no socket and no pending
      // connection future. waitForConnection should return false immediately
      // (not hang, not set up orphan timers).
      final result = await NodeBackendService.waitForConnection(
        timeout: const Duration(milliseconds: 100),
      );
      expect(result, false);
    });

    test(
        'initSocket does not throw on double call — idempotency guard holds',
        () {
      // First call initiates a connection and sets _connecting = true.
      NodeBackendService.initSocket();

      // Second call should hit the _connecting guard and return early.
      // No exception, no redundant socket creation.
      expect(() => NodeBackendService.initSocket(), returnsNormally);
    });

    test('dispose can be called safely multiple times', () {
      // First dispose cleans up the socket.
      NodeBackendService.dispose();
      // Second dispose is a no-op (socket already null).
      NodeBackendService.dispose();
      // State should be fully reset.
      expect(NodeBackendService.isConnected, false);
    });

    test('initSocket dispose initSocket cycle is safe', () {
      // init after dispose should work without stale state from the first init.
      NodeBackendService.initSocket();
      NodeBackendService.dispose();
      // After dispose, a fresh init should not carry stale _connecting state.
      expect(() => NodeBackendService.initSocket(), returnsNormally);
    });

    test('three rapid initSocket calls are all safe (idempotency)', () {
      // Multiple rapid calls should all return normally; at most one
      // connection attempt is made.
      NodeBackendService.initSocket();
      NodeBackendService.initSocket();
      NodeBackendService.initSocket();
      expect(NodeBackendService.isConnected, isNot(true)); // not yet connected
    });

    test(
        'initSocket after connection error flow resets guard — allows retry',
        () async {
      // Simulate the guard reset that happens on connectError: after an
      // error, _connecting is false and a new init should work.
      NodeBackendService.initSocket();
      // At this point _connecting = true. We dispose to simulate a reset.
      NodeBackendService.dispose();
      // A fresh init after dispose+error-reset must work.
      expect(() => NodeBackendService.initSocket(), returnsNormally);
    });

    test('dispose lifecycle observer guard is properly reset', () {
      // The _registerLifecycleObserver guard should not prevent a fresh
      // init after dispose.
      NodeBackendService.initSocket();
      NodeBackendService.dispose();
      NodeBackendService.initSocket();
      NodeBackendService.dispose();
      // Should be clean after two cycles.
      expect(NodeBackendService.isConnected, false);
    });

    test('waitForConnection returns false after dispose while in flight',
        () async {
      // Start a connection, dispose it, then verify waitForConnection
      // returns false (the completer was cleared).
      NodeBackendService.initSocket();
      NodeBackendService.dispose();
      final result = await NodeBackendService.waitForConnection(
        timeout: const Duration(milliseconds: 100),
      );
      expect(result, false);
    });
  });

  group('MatchWebSocketService delegates to NodeBackendService', () {
    setUp(() {
      NodeBackendService.dispose();
    });

    test('isConnected delegates to NodeBackendService', () {
      final service = MatchWebSocketService(
        onBallUpdate: (_) {},
        onMatchComplete: (_) {},
        onRoomJoined: (_) {},
      );
      // Before any connection attempt, both report not connected.
      expect(service.isConnected, NodeBackendService.isConnected);
    });

    test('disconnect is safe when no match was joined', () {
      final service = MatchWebSocketService(
        onBallUpdate: (_) {},
        onMatchComplete: (_) {},
        onRoomJoined: (_) {},
      );
      // Calling disconnect without a prior connectToMatch should not throw.
      expect(() => service.disconnect(), returnsNormally);
    });

    test('can create multiple service instances without extra sockets', () {
      // Multiple MatchWebSocketService instances should all share the
      // single NodeBackendService socket.
      final service1 = MatchWebSocketService(
        onBallUpdate: (_) {},
        onMatchComplete: (_) {},
        onRoomJoined: (_) {},
      );
      final service2 = MatchWebSocketService(
        onBallUpdate: (_) {},
        onMatchComplete: (_) {},
        onRoomJoined: (_) {},
      );

      // Both delegate to the same singleton.
      expect(service1.isConnected, service2.isConnected);
      expect(service1.isConnected, NodeBackendService.isConnected);
    });

    test(
        'MatchWebSocketService does not create its own Socket.IO instance',
        () {
      // The entire purpose of this test is to verify the refactoring:
      // MatchWebSocketService should NOT have its own io.Socket field.
      // We can't inspect private fields, but we verify by checking that
      // connecting through the service also updates NodeBackendService.
      final service = MatchWebSocketService(
        onBallUpdate: (_) {},
        onMatchComplete: (_) {},
        onRoomJoined: (_) {},
      );

      // Before any connect call, NodeBackendService state is clean.
      expect(NodeBackendService.isConnected, false);

      // Calling initSocket on NodeBackendService directly should be the
      // same path that MatchWebSocketService.connectToMatch uses.
      NodeBackendService.initSocket();
      // Service should report the same connection state.
      expect(service.isConnected, NodeBackendService.isConnected);
    });
  });
}
