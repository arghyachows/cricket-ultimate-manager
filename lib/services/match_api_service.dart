import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/node_backend_service.dart';

/// API service for match-related HTTP calls.
/// Extracts REST API calls from MatchNotifier into a dedicated service.
class MatchApiService {
  static String get _baseUrl => NodeBackendService.baseUrl;

  /// Start a match on the Node.js backend and return success status.
  static Future<bool> startMatch({
    required String matchId,
    required Map<String, dynamic> homeSquad,
    required Map<String, dynamic> awaySquad,
    required String format,
    required int overs,
    required String difficulty,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/match/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matchId': matchId,
          'homeSquad': homeSquad,
          'awaySquad': awaySquad,
          'format': format,
          'overs': overs,
          'difficulty': difficulty,
        }),
      );
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Poll for match completion status (fallback when WebSocket unavailable).
  static Future<Map<String, dynamic>?> pollMatchStatus(String matchId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/match/$matchId/status'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Save match rewards to the backend.
  static Future<void> saveRewards({
    required String matchId,
    required int coins,
    required int xp,
    required bool won,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/match/$matchId/rewards'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'coins': coins, 'xp': xp, 'won': won}),
      );
    } catch (e) {
      // ignore errors for reward persistence
    }
  }
}
