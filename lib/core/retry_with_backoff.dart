import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Configuration for exponential backoff retry behaviour.
class RetryConfig {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Base delay in milliseconds for the first retry.
  final int baseDelayMs;

  /// Whether to apply random jitter (±25%) to each delay.
  final bool useJitter;

  /// HTTP status codes that are considered retryable (5xx server errors).
  final List<int> retryableStatuses;

  const RetryConfig({
    this.maxAttempts = 5,
    this.baseDelayMs = 1000,
    this.useJitter = true,
    this.retryableStatuses = const [502, 503, 504],
  });

  /// Exponential backoff delays: ~1s, ~2s, ~4s, ~8s, ~16s
  Duration delayForAttempt(int attempt) {
    assert(attempt >= 1);
    final raw = baseDelayMs * pow(2, attempt - 1).toInt();
    if (!useJitter) return Duration(milliseconds: raw);

    // Add ±25% jitter to avoid thundering herd
    final rng = Random();
    final jitter = (raw * (0.75 + rng.nextDouble() * 0.5)).toInt();
    return Duration(milliseconds: jitter);
  }
}

/// Whether an HTTP status code should trigger a retry (5xx or 429).
bool isRetryableHttpStatus(int statusCode) {
  if (statusCode >= 500 && statusCode < 600) return true;
  if (statusCode == 429) return true;
  return false;
}

/// Whether an exception type represents a transient network failure.
bool isTransientError(Object error) {
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;
  if (error is HandshakeException) return true;
  if (error is HttpException) return true;
  return false;
}

/// A tagged result that distinguishes a successful call from an exhausted
/// retry cycle.
class RetryResult<T> {
  final T? value;
  final Object? error;
  final int attemptsUsed;
  final bool succeeded;

  const RetryResult({
    this.value,
    this.error,
    required this.attemptsUsed,
    required this.succeeded,
  });
}

/// Execute [fn] with exponential-backoff retry.
///
/// Returns a [RetryResult] describing the outcome.
/// Exceptions that are transient (network/Socket/Timeout) cause retry.
/// The optional [isRetryable] callback allows logical retry decisions
/// (e.g. when HTTP 5xx is returned as a successful response).
Future<RetryResult<T>> retryWithBackoff<T>({
  required Future<T> Function() fn,
  RetryConfig config = const RetryConfig(),
  bool Function(T result)? isRetryable,
  Duration timeout = const Duration(seconds: 10),
}) async {
  T? lastValue;
  Object? lastError;
  int attempt = 0;

  for (; attempt < config.maxAttempts; attempt++) {
    try {
      lastValue = await fn().timeout(timeout);
      lastError = null;

      // If the caller provided a retryable-checker, consult it
      if (isRetryable != null && isRetryable(lastValue as T)) {
        // This is a retryable logical failure (e.g. HTTP 5xx)
        if (attempt + 1 < config.maxAttempts) {
          await Future.delayed(config.delayForAttempt(attempt + 1));
          continue;
        }
        return RetryResult<T>(
          value: lastValue,
          attemptsUsed: attempt + 1,
          succeeded: false,
        );
      }

      return RetryResult<T>(
        value: lastValue,
        attemptsUsed: attempt + 1,
        succeeded: true,
      );
    } on TimeoutException catch (e) {
      lastError = e;
      // Transient — retry
    } catch (e) {
      if (isTransientError(e)) {
        lastError = e;
        // Transient — retry
      } else {
        // Non-transient — surface immediately
        return RetryResult<T>(
          attemptsUsed: attempt + 1,
          succeeded: false,
          error: e,
        );
      }
    }

    if (attempt + 1 < config.maxAttempts) {
      await Future.delayed(config.delayForAttempt(attempt + 1));
    }
  }

  return RetryResult<T>(
    value: lastValue,
    error: lastError,
    attemptsUsed: attempt,
    succeeded: false,
  );
}