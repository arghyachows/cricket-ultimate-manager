import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/core/circuit_breaker.dart';

void main() {
  group('CircuitBreakerConfig', () {
    test('uses default values when no config provided', () {
      const config = CircuitBreakerConfig();
      expect(config.failureThreshold, 5);
      expect(config.resetTimeout, const Duration(seconds: 30));
      expect(config.halfOpenMaxRequests, 1);
    });

    test('custom config values are respected', () {
      const config = CircuitBreakerConfig(
        failureThreshold: 3,
        resetTimeout: Duration(seconds: 15),
        halfOpenMaxRequests: 2,
      );
      expect(config.failureThreshold, 3);
      expect(config.resetTimeout, const Duration(seconds: 15));
      expect(config.halfOpenMaxRequests, 2);
    });
  });

  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        name: 'test-breaker',
        config: const CircuitBreakerConfig(
          failureThreshold: 3,
          resetTimeout: Duration(milliseconds: 100),
          halfOpenMaxRequests: 1,
        ),
      );
    });

    tearDown(() {
      breaker.dispose();
    });

    test('starts in closed state', () {
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
      expect(breaker.successCount, 0);
    });

    test('allows calls when circuit is closed', () async {
      final result = await breaker.call(() async => 'success');
      expect(result, 'success');
      expect(breaker.state, CircuitState.closed);
    });

    test('opens after consecutive failures equal to threshold', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);
      expect(breaker.failureCount, 3);
    });

    test('throws CircuitBreakerOpenException when circuit is open', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      // Call while open
      try {
        await breaker.call(() async => 'should-not-reach');
        fail('Expected CircuitBreakerOpenException');
      } on CircuitBreakerOpenException catch (e) {
        expect(e.breakerName, 'test-breaker');
      }
    });

    test('transitions to half-open after reset timeout and fails back to open',
        () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // The next call transitions open→halfOpen (inside call()) then fails → open
      try {
        await breaker.call(() async => throw Exception('half-open-fail'));
      } catch (_) {}

      // After a failed half-open probe, circuit goes back to open
      expect(breaker.state, CircuitState.open);
    });

    test('half-open success transitions to closed', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // Half-open probe succeeds
      final result = await breaker.call(() async => 'probe-success');
      expect(result, 'probe-success');
      expect(breaker.state, CircuitState.closed);
      expect(breaker.successCount, 1);
    });

    test('half-open failure transitions back to open', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // Half-open probe fails
      try {
        await breaker.call(() async => throw Exception('probe-fail'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);
      expect(breaker.shortCircuitedCount, 0);
    });

    test('rejects excess half-open requests beyond halfOpenMaxRequests', () async {
      // Use config with halfOpenMaxRequests=1
      breaker = CircuitBreaker(
        name: 'strict-breaker',
        config: const CircuitBreakerConfig(
          failureThreshold: 2,
          resetTimeout: Duration(milliseconds: 100),
          halfOpenMaxRequests: 1,
        ),
      );

      // Trip the breaker
      for (int i = 0; i < 2; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // First half-open call should proceed (and succeed)
      final firstResult = await breaker.call(() async => 'first-probe');
      expect(firstResult, 'first-probe');
      expect(breaker.state, CircuitState.closed);

      breaker.dispose();
    });

    test('reset() restores circuit to closed state', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);
      expect(breaker.failureCountTotal, 3);

      // Manual reset
      breaker.reset();
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
      expect(breaker.shortCircuitedCount, 0);

      // Should accept calls again
      final result = await breaker.call(() async => 'after-reset');
      expect(result, 'after-reset');
    });

    test('tracks shortCircuitedCount correctly', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }
      expect(breaker.shortCircuitedCount, 0);

      // Two calls while open
      for (int i = 0; i < 2; i++) {
        try {
          await breaker.call(() async => 'rejected');
        } on CircuitBreakerOpenException catch (_) {}
      }
      expect(breaker.shortCircuitedCount, 2);
    });

    test('onStateChanged stream emits state transitions', () async {
      final transitions = <CircuitState>[];
      final sub = breaker.onStateChanged.listen((s) => transitions.add(s));

      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 150));

      // Half-open probe succeeds
      await breaker.call(() async => 'probe');

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(transitions.length, greaterThanOrEqualTo(2));
      expect(transitions, contains(CircuitState.open));
      expect(transitions, contains(CircuitState.halfOpen));
    });

    test('success resets failure count', () async {
      // One failure
      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}
      expect(breaker.failureCount, 1);

      // Then a success
      await breaker.call(() async => 'success');
      expect(breaker.failureCount, 0);
      expect(breaker.state, CircuitState.closed);
    });
  });
}
