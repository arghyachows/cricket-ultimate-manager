import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to interact with Cloudflare Worker for quick match simulation
class CloudflareQuickMatchService {
  // TODO: Update this URL after deploying Cloudflare Worker
  // Get your worker URL from: npx wrangler deploy
  static const String workerUrl = 'https://cricket-match-simulator.arghyachowdhury2610.workers.dev';
  
  // For local testing, use:
  // static const String workerUrl = 'http://localhost:8787';
  
  /// Start a quick match simulation
  /// Returns true if successfully started, false otherwise
  static Future<bool> startQuickMatch({
    required String matchId,
    required Map<String, dynamic> matchConfig,
  }) async {
    try {
      print('🚀 Cloudflare: Starting quick match $matchId');
      print('🌐 Worker URL: $workerUrl/api/quick-match/start');
      
      final response = await http.post(
        Uri.parse('$workerUrl/api/quick-match/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'matchId': matchId,
          'config': matchConfig,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Cloudflare response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Cloudflare success: $data');
        return data['success'] == true;
      }
      
      print('❌ Cloudflare quick match start failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e, stackTrace) {
      print('❌ Cloudflare quick match start error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get current match state
  static Future<Map<String, dynamic>?> getMatchState(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$workerUrl/api/quick-match/state/$matchId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Cloudflare quick match state error: $e');
      return null;
    }
  }

  /// Stop a running match simulation
  static Future<bool> stopMatch(String matchId) async {
    try {
      final response = await http.post(
        Uri.parse('$workerUrl/api/quick-match/stop/$matchId'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Cloudflare quick match stop error: $e');
      return false;
    }
  }
}
