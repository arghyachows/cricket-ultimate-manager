import 'dart:convert';
import 'package:http/http.dart' as http;

class LocalMultiplayerService {
  static const String baseUrl = 'http://localhost:3000';
  
  static Future<bool> startMultiplayerMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    try {
      print('🚀 Local Backend: Starting multiplayer match $matchId');
      print('📦 Config: $config');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/multiplayer/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'matchId': matchId,
          'config': config,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Local Backend response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Local Backend success: $data');
        return data['success'] == true;
      }
      
      print('❌ Local Backend failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e, stackTrace) {
      print('❌ Local Backend error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getMatchState(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/multiplayer/$matchId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Local Backend state error: $e');
      return null;
    }
  }

  static Future<bool> stopMatch(String matchId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/multiplayer/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'matchId': matchId}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Local Backend stop error: $e');
      return false;
    }
  }
}
