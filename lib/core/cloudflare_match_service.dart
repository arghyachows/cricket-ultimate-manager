import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to communicate with Cloudflare Worker for match simulation
class CloudflareMatchService {
  // TODO: Replace with your deployed Worker URL
  static const String workerUrl = 'https://cricket-match-simulator.arghyachowdhury2610.workers.dev';
  
  /// Start match simulation on Cloudflare Durable Object
  static Future<bool> startMatchSimulation(String matchId) async {
    try {
      final response = await http.post(
        Uri.parse('$workerUrl/api/match/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'match_id': matchId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        print('Worker error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Failed to start match simulation: $e');
      return false;
    }
  }

  /// Get current match state from Durable Object
  static Future<Map<String, dynamic>?> getMatchState(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$workerUrl/api/match/state/$matchId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Failed to get match state: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Failed to get match state: $e');
      return null;
    }
  }

  /// Stop match simulation
  static Future<bool> stopMatchSimulation(String matchId) async {
    try {
      final response = await http.post(
        Uri.parse('$workerUrl/api/match/stop/$matchId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('Failed to stop match simulation: $e');
      return false;
    }
  }

  /// Health check
  static Future<bool> isWorkerHealthy() async {
    try {
      final response = await http.get(
        Uri.parse('$workerUrl/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
