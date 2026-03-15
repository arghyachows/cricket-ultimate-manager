import 'dart:convert';
import 'package:http/http.dart' as http;

/// Profanity filter using PurgoMalum API
/// Free, unlimited requests, no API key required
/// https://www.purgomalum.com/
class ProfanityFilter {
  static const _baseUrl = 'https://www.purgomalum.com/service';
  static final Map<String, bool> _cache = {};
  static const _cacheMaxSize = 1000;

  /// Check if text contains profanity using PurgoMalum API
  static Future<bool> containsProfanity(String text) async {
    if (text.isEmpty) return false;

    final cacheKey = text.toLowerCase().trim();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('$_baseUrl/containsprofanity?text=$encodedText');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final isProfane = response.body.toLowerCase() == 'true';
        _cacheResult(cacheKey, isProfane);
        return isProfane;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clean text by replacing profanity with asterisks
  static Future<String> cleanText(String text) async {
    if (text.isEmpty) return text;

    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('$_baseUrl/plain?text=$encodedText');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        return response.body;
      }
      
      return text;
    } catch (e) {
      return text;
    }
  }

  /// Clean text with custom replacement character
  static Future<String> cleanTextWithReplacement(
    String text, 
    String replacement,
  ) async {
    if (text.isEmpty) return text;

    try {
      final encodedText = Uri.encodeComponent(text);
      final encodedReplacement = Uri.encodeComponent(replacement);
      final url = Uri.parse(
        '$_baseUrl/plain?text=$encodedText&fill_text=$encodedReplacement'
      );
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        return response.body;
      }
      
      return text;
    } catch (e) {
      return text;
    }
  }

  /// Get JSON response with detailed profanity information
  static Future<Map<String, dynamic>> analyzeProfanity(String text) async {
    if (text.isEmpty) {
      return {'result': text, 'hasProfanity': false};
    }

    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('$_baseUrl/json?text=$encodedText');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'result': data['result'] ?? text,
          'hasProfanity': data['result'] != text,
        };
      }
      
      return {
        'result': text,
        'hasProfanity': false,
      };
    } catch (e) {
      return {
        'result': text,
        'hasProfanity': false,
      };
    }
  }

  static void _cacheResult(String key, bool isProfane) {
    if (_cache.length >= _cacheMaxSize) {
      final keysToRemove = _cache.keys.take(_cacheMaxSize ~/ 2).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = isProfane;
  }

  static String get errorMessage =>
      'Inappropriate language detected. Please use respectful language.';

  /// Validate text and return error message if profanity found
  static Future<String?> validate(String? text) async {
    if (text == null || text.isEmpty) return null;
    final isProfane = await containsProfanity(text);
    return isProfane ? errorMessage : null;
  }

  /// Username validation with profanity check
  static Future<String?> validateUsername(String? username) async {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    final isProfane = await containsProfanity(username);
    if (isProfane) {
      return errorMessage;
    }
    
    return null;
  }

  /// Team name validation with profanity check
  static Future<String?> validateTeamName(String? teamName) async {
    if (teamName == null || teamName.isEmpty) {
      return 'Team name is required';
    }
    if (teamName.length < 3) {
      return 'Team name must be at least 3 characters';
    }
    if (teamName.length > 30) {
      return 'Team name must be less than 30 characters';
    }
    
    final isProfane = await containsProfanity(teamName);
    if (isProfane) {
      return errorMessage;
    }
    
    return null;
  }

  /// Display name validation with profanity check
  static Future<String?> validateDisplayName(String? displayName) async {
    if (displayName == null || displayName.isEmpty) {
      return null;
    }
    if (displayName.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    if (displayName.length > 30) {
      return 'Display name must be less than 30 characters';
    }
    
    final isProfane = await containsProfanity(displayName);
    if (isProfane) {
      return errorMessage;
    }
    
    return null;
  }

  /// Generic text validation with profanity check
  static Future<String?> validateText(
    String? text, {
    String fieldName = 'Text',
    int minLength = 1,
    int maxLength = 100,
    bool required = true,
  }) async {
    if (text == null || text.isEmpty) {
      return required ? '$fieldName is required' : null;
    }
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (text.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    
    final isProfane = await containsProfanity(text);
    if (isProfane) {
      return errorMessage;
    }
    
    return null;
  }

  /// Synchronous username validation (basic checks only, no profanity)
  /// Use for form validators, then call validateUsername() on submit
  static String? validateUsernameSync(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  /// Synchronous team name validation (basic checks only, no profanity)
  /// Use for form validators, then call validateTeamName() on submit
  static String? validateTeamNameSync(String? teamName) {
    if (teamName == null || teamName.isEmpty) {
      return 'Team name is required';
    }
    if (teamName.length < 3) {
      return 'Team name must be at least 3 characters';
    }
    if (teamName.length > 30) {
      return 'Team name must be less than 30 characters';
    }
    return null;
  }

  /// Synchronous display name validation (basic checks only, no profanity)
  /// Use for form validators, then call validateDisplayName() on submit
  static String? validateDisplayNameSync(String? displayName) {
    if (displayName == null || displayName.isEmpty) {
      return null; // Optional field
    }
    if (displayName.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    if (displayName.length > 30) {
      return 'Display name must be less than 30 characters';
    }
    return null;
  }

  /// Synchronous generic text validation (basic checks only, no profanity)
  static String? validateTextSync(
    String? text, {
    String fieldName = 'Text',
    int minLength = 1,
    int maxLength = 100,
    bool required = true,
  }) {
    if (text == null || text.isEmpty) {
      return required ? '$fieldName is required' : null;
    }
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (text.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    return null;
  }

  /// Clear the cache
  static void clearCache() {
    _cache.clear();
  }
}
