import 'dart:async';

/// Circuit breaker states.
enum CircuitState { closed, open, halfOpen }

/// Configuration for the circuit breaker.
class CircuitBreakerConfig {
  /// Number of consecutive failures before the circuit opens.
  final int failureThreshold;

  /// Duration to wait before transitioning from open to half-open.
  final Duration resetTimeout;

  /// Maximum number of test requests in half-open state.
  final int halfOpenMaxRequests;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.halfOpenMaxRequests = 1,
  });
}

/// A circuit breaker for match service calls.
///
/// Prevents cascading failures by short-circuiting calls when the
/// downstream service is unhealthy, allowing it to recover.
class CircuitBreaker {
  final CircuitBreakerConfig config;
  final String name;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _halfOpenRequests = 0;
  DateTime? _openedAt;
  int _successCount = 0;
  int _failureCountTotal = 0;
  int _shortCircuitedCount = 0;

  /// Stream of state changes for observability.
  final _stateController = StreamController<CircuitState>.broadcast();
  Stream<CircuitState> get onStateChanged => _stateController.stream;

  CircuitBreaker({required this.name, CircuitBreakerConfig? config})
      : config = config ?? const CircuitBreakerConfig();

  CircuitState get state => _state;
  int get failureCount => _failureCount;
  int get successCount => _successCount;
  int get failureCountTotal => _failureCountTotal;
  int get shortCircuitedCount => _shortCircuitedCount;

  /// Execute [fn] through the circuit breaker.
  ///
  /// Throws [CircuitBreakerOpenException] if the circuit is open.
  Future<T> call<T>(Future<T> Function() fn) async {
    if (_state == CircuitState.open) {
      // Check if reset timeout has elapsed
      if (_openedAt != null &&
          DateTime.now().difference(_openedAt!) >= config.resetTimeout) {
        _state = CircuitState.halfOpen;
        _halfOpenRequests = 0;
        _stateController.add(_state);
      } else {
        _shortCircuitedCount++;
        throw CircuitBreakerOpenException(name);
      }
    }

    if (_state == CircuitState.halfOpen &&
        _halfOpenRequests >= config.halfOpenMaxRequests) {
      _shortCircuitedCount++;
      throw CircuitBreakerOpenException(name);
    }

    if (_state == CircuitState.halfOpen) {
      _halfOpenRequests++;
    }

    try {
      final result = await fn();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _successCount++;
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      _openedAt = null;
      _halfOpenRequests = 0;
      _stateController.add(_state);
    }
  }

  void _onFailure() {
    _failureCount++;
    _failureCountTotal++;
    if (_state == CircuitState.halfOpen ||
        (_state == CircuitState.closed &&
            _failureCount >= config.failureThreshold)) {
      _state = CircuitState.open;
      _openedAt = DateTime.now();
      _halfOpenRequests = 0;
      _stateController.add(_state);
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _halfOpenRequests = 0;
    _openedAt = null;
    _stateController.add(_state);
  }

  void dispose() {
    _stateController.close();
  }
}

/// Thrown when a call is rejected because the circuit is open.
class CircuitBreakerOpenException implements Exception {
  final String breakerName;
  CircuitBreakerOpenException(this.breakerName);

  @override
  String toString() => 'Circuit "$breakerName" is open — call rejected';
}
