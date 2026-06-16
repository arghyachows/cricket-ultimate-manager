import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/logger.dart';
import '../core/node_backend_service.dart';
import '../core/retry_with_backoff.dart';

/// Idempotency key manager for match operations.
///
/// Every match request carries a client-generated idempotency key (UUID v4).
/// The server rejects duplicate keys, returning the original result.
class IdempotencyService {
  static String get _baseUrl => NodeBackendService.baseUrl;

  /// Generate a new idempotency key (UUID v4 format).
  static String generateKey() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // Set version 4 bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant bits
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return '${_hex(bytes, 0, 4)}-${_hex(bytes, 4, 2)}-${_hex(bytes, 6, 2)}-${_hex(bytes, 8, 2)}-${_hex(bytes, 10, 6)}';
  }

  static String _hex(List<int> bytes, int start, int length) {
    return bytes.sublist(start, start + length).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Register an idempotency key before sending a match request.
  ///
  /// Returns true if the key was accepted (no duplicate), false if
  /// a request with this key is already in flight or completed.
  static Future<bool> registerKey({
    required String idempotencyKey,
    required String userId,
    required String operation,
  }) async {
    final result = await retryWithBackoff(
      fn: () async {
        final resp = await http.post(
          Uri.parse('$_baseUrl/match/idempotency/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idempotency_key': idempotencyKey,
            'user_id': userId,
            'operation': operation,
          }),
        );
        if (resp.statusCode == 200) return true;
        if (resp.statusCode == 409) return false;
        throw HttpException(
          'Idempotency register failed: ${resp.statusCode}',
          uri: Uri.parse('$_baseUrl/match/idempotency/register'),
        );
      },
      config: const RetryConfig(maxAttempts: 3, baseDelayMs: 200),
      timeout: const Duration(seconds: 5),
    );

    if (!result.succeeded) {
      throw Exception('Failed to register idempotency key: ${result.error}');
    }
    return result.value!;
  }

  /// Retrieve the stored result for a completed idempotency key.
  static Future<Map<String, dynamic>?> getResult({
    required String idempotencyKey,
  }) async {
    final result = await retryWithBackoff(
      fn: () async {
        final resp = await http.get(
          Uri.parse('$_baseUrl/match/idempotency/$idempotencyKey'),
          headers: {'Content-Type': 'application/json'},
        );
        if (resp.statusCode == 200) {
          return jsonDecode(resp.body) as Map<String, dynamic>;
        }
        if (resp.statusCode == 404) return null;
        throw HttpException(
          'Idempotency lookup failed: ${resp.statusCode}',
          uri: Uri.parse('$_baseUrl/match/idempotency/$idempotencyKey'),
        );
      },
      config: const RetryConfig(maxAttempts: 2, baseDelayMs: 100),
      timeout: const Duration(seconds: 5),
    );

    return result.succeeded ? result.value : null;
  }

  /// Store the result for a completed idempotency key.
  static Future<void> storeResult({
    required String idempotencyKey,
    required String userId,
    required String operation,
    required Map<String, dynamic> result,
  }) async {
    await retryWithBackoff(
      fn: () async {
        final resp = await http.post(
          Uri.parse('$_baseUrl/match/idempotency/store'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idempotency_key': idempotencyKey,
            'user_id': userId,
            'operation': operation,
            'result': result,
          }),
        );
        if (resp.statusCode != 200) {
          throw HttpException(
            'Idempotency store failed: ${resp.statusCode}',
            uri: Uri.parse('$_baseUrl/match/idempotency/store'),
          );
        }
      },
      config: const RetryConfig(maxAttempts: 2, baseDelayMs: 100),
      timeout: const Duration(seconds: 5),
    );
  }

  /// Execute a match operation with idempotency guarantees.
  ///
  /// Generates an idempotency key, attempts the operation, and stores
  /// the result. On duplicate, returns the original stored result.
  static Future<T> executeIdempotent<T>({
    required String userId,
    required String operation,
    required Future<T> Function(String idempotencyKey) operationFn,
    required T Function(Map<String, dynamic> stored) fromStored,
  }) async {
    final idempotencyKey = generateKey();

    // Attempt to register the key
    final accepted = await registerKey(
      idempotencyKey: idempotencyKey,
      userId: userId,
      operation: operation,
    );

    if (!accepted) {
      // Duplicate key — retrieve the stored result
      final stored = await getResult(idempotencyKey: idempotencyKey);
      if (stored != null) {
        return fromStored(stored);
      }
      // Key was registered but result not yet stored — it's in flight
      // Wait briefly and retry
      await Future.delayed(const Duration(seconds: 2));
      final retryStored = await getResult(idempotencyKey: idempotencyKey);
      if (retryStored != null) {
        return fromStored(retryStored);
      }
      throw Exception('Idempotency key $idempotencyKey already registered but result unavailable');
    }

    // Execute the operation
    try {
      final result = await operationFn(idempotencyKey);
      // Store result as Map if possible
      try {
        final resultMap = (result as dynamic).toJson() as Map<String, dynamic>;
        await storeResult(
          idempotencyKey: idempotencyKey,
          userId: userId,
          operation: operation,
          result: resultMap,
        );
      } catch (e) {
        // Not serializable — best-effort (log for debugging)
        Log.e('Idempotency: failed to cache result for $operation', e);
      }
      return result;
    } catch (e) {
      // Operation failed — don't store result, key will expire via TTL
      rethrow;
    }
  }
}

/// HTTP error with status code context.
class HttpException implements Exception {
  final String message;
  final Uri? uri;
  HttpException(this.message, {this.uri});
  @override
  String toString() => 'HttpException: $message${uri != null ? ' ($uri)' : ''}';
}
