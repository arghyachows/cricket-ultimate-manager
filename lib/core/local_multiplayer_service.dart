import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'logger.dart';

class LocalMultiplayerService {
  static String get baseUrl => AppConfig.backendUrl;
  
  static Future<bool> startMultiplayerMatch({
    required String matchId,
    required Map<String, dynamic> config,
  }) async {
    try {
      Log.i('Local Backend: Starting multiplayer match $matchId');
      Log.d('Config: $config');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/multiplayer/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'matchId': matchId,
          'config': config,
        }),
      ).timeout(const Duration(seconds: 10));

      Log.d('Local Backend response: ${response.statusCode}');
      Log.d('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Log.i('Local Backend success');
        return data['success'] == true;
      }
      
      Log.e('Local Backend failed: ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      Log.e('Local Backend error', e, stackTrace);
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
      Log.e('Local Backend state error', e);
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
      Log.e('Local Backend stop error', e);
      return false;
    }
  }
}
