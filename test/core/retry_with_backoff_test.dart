import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/core/retry_with_backoff.dart';

void main() {
  group('RetryConfig', () {
    test('uses default values when no config provided', () {
      const config = RetryConfig();
      expect(config.maxAttempts, 5);
      expect(config.baseDelayMs, 1000);
      expect(config.useJitter, true);
      expect(config.retryableStatuses, [502, 503, 504]);
    });

    test('delayForAttempt computes exponential backoff without jitter', () {
      const config = RetryConfig(useJitter: false);
      expect(config.delayForAttempt(1).inMilliseconds, 1000);
      expect(config.delayForAttempt(2).inMilliseconds, 2000);
      expect(config.delayForAttempt(3).inMilliseconds, 4000);
      expect(config.delayForAttempt(4).inMilliseconds, 8000);
    });

    test('delayForAttempt with jitter stays within ±25% range', () {
      const config = RetryConfig(useJitter: true);
      // Run 100 samples per attempt to verify jitter bounds
      for (int attempt = 1; attempt <= 4; attempt++) {
        for (int i = 0; i < 100; i++) {
          final delay = config.delayForAttempt(attempt);
          final base = 1000 * (1 << (attempt - 1));
          expect(delay.inMilliseconds, greaterThanOrEqualTo((base * 0.75).floor()));
          expect(delay.inMilliseconds, lessThanOrEqualTo((base * 1.25).ceil()));
        }
      }
    });

    test('custom config values are respected', () {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelayMs: 500,
        useJitter: false,
        retryableStatuses: [500, 503],
      );
      expect(config.maxAttempts, 3);
      expect(config.baseDelayMs, 500);
      expect(config.delayForAttempt(1).inMilliseconds, 500);
      expect(config.delayForAttempt(2).inMilliseconds, 1000);
    });
  });

  group('isRetryableHttpStatus', () {
    test('returns true for 5xx status codes', () {
      expect(isRetryableHttpStatus(500), isTrue);
      expect(isRetryableHttpStatus(502), isTrue);
      expect(isRetryableHttpStatus(503), isTrue);
      expect(isRetryableHttpStatus(504), isTrue);
    });

    test('returns true for 429 Too Many Requests', () {
      expect(isRetryableHttpStatus(429), isTrue);
    });

    test('returns false for 4xx and 2xx status codes', () {
      expect(isRetryableHttpStatus(200), isFalse);
      expect(isRetryableHttpStatus(400), isFalse);
      expect(isRetryableHttpStatus(401), isFalse);
      expect(isRetryableHttpStatus(404), isFalse);
      expect(isRetryableHttpStatus(409), isFalse);
    });
  });

  group('isTransientError', () {
    test('returns true for TimeoutException', () {
      expect(isTransientError(TimeoutException('timeout')), isTrue);
    });

    test('returns true for SocketException', () {
      expect(isTransientError(const SocketException('socket error')), isTrue);
    });

    test('returns true for HandshakeException', () {
      expect(isTransientError(HandshakeException('handshake error')), isTrue);
    });

    test('returns true for HttpException', () {
      expect(isTransientError(HttpException('http error')), isTrue);
    });

    test('returns false for generic Exception', () {
      expect(isTransientError(Exception('generic')), isFalse);
    });

    test('returns false for ArgumentError', () {
      expect(isTransientError(ArgumentError('bad arg')), isFalse);
    });
  });

  group('RetryResult', () {
    test('constructs a success result', () {
      const result = RetryResult(value: 'ok', attemptsUsed: 1, succeeded: true);
      expect(result.value, 'ok');
      expect(result.attemptsUsed, 1);
      expect(result.succeeded, isTrue);
      expect(result.error, isNull);
    });

    test('constructs a failure result', () {
      final error = Exception('fail');
      final result = RetryResult<int>(
        attemptsUsed: 3,
        succeeded: false,
        error: error,
      );
      expect(result.value, isNull);
      expect(result.attemptsUsed, 3);
      expect(result.succeeded, isFalse);
      expect(result.error, error);
    });
  });

  group('retryWithBackoff', () {
    test('returns success on first attempt when fn succeeds', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          return 'ok';
        },
        config: const RetryConfig(maxAttempts: 3, useJitter: false),
      );
      expect(result.succeeded, isTrue);
      expect(result.value, 'ok');
      expect(callCount, 1);
    });

    test('retries on TimeoutException and eventually succeeds', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          if (callCount < 3) {
            throw TimeoutException('timeout');
          }
          return 'ok';
        },
        config: const RetryConfig(maxAttempts: 3, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.succeeded, isTrue);
      expect(result.value, 'ok');
      expect(callCount, 3);
    });

    test('returns failure after exhausting all retries on transient errors', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          throw const SocketException('connection refused');
        },
        config: const RetryConfig(maxAttempts: 3, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.succeeded, isFalse);
      expect(callCount, 3);
      expect(result.error, isA<SocketException>());
    });

    test('does not retry on non-transient errors', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          throw ArgumentError('bad input');
        },
        config: const RetryConfig(maxAttempts: 3, useJitter: false),
      );
      expect(result.succeeded, isFalse);
      expect(callCount, 1);
    });

    test('uses isRetryable callback for logical retry decisions', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          return callCount;
        },
        isRetryable: (value) => value < 3,
        config: const RetryConfig(maxAttempts: 3, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.succeeded, isTrue);
      expect(result.value, 3);
      expect(callCount, 3);
    });

    test('isRetryable returning true indefinitely exhausts attempts', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          return 'always-retryable';
        },
        isRetryable: (value) => true,
        config: const RetryConfig(maxAttempts: 3, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.succeeded, isFalse);
      expect(result.value, 'always-retryable');
      expect(callCount, 3);
    });

    test('respects timeout and fails with TimeoutException', () async {
      final result = await retryWithBackoff(
        fn: () async {
          await Future.delayed(const Duration(seconds: 10));
          return 'too-late';
        },
        config: const RetryConfig(maxAttempts: 1, useJitter: false),
        timeout: const Duration(milliseconds: 10),
      );
      expect(result.succeeded, isFalse);
      expect(result.error, isA<TimeoutException>());
    });

    test('tracks attemptsUsed correctly', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          if (callCount < 3) throw const SocketException('retry');
          return 'ok';
        },
        config: const RetryConfig(maxAttempts: 5, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.attemptsUsed, 3);
      expect(result.succeeded, isTrue);
    });

    test('handles mixed transient and non-transient errors correctly', () async {
      int callCount = 0;
      final result = await retryWithBackoff(
        fn: () async {
          callCount++;
          if (callCount == 1) throw const SocketException('transient');
          if (callCount == 2) throw ArgumentError('non-transient');
          return 'ok';
        },
        config: const RetryConfig(maxAttempts: 5, useJitter: false, baseDelayMs: 10),
        timeout: const Duration(seconds: 5),
      );
      expect(result.succeeded, isFalse);
      expect(callCount, 2);
      expect(result.error, isA<ArgumentError>());
    });
  });
}
