/// Simple structured logger for the app.
///
/// Provides log level filtering so debug prints can stay in the codebase
/// without cluttering release builds. In production (not debug mode),
/// only warnings and errors are printed.
///
/// Usage:
///   Log.d('message');  // Debug (skipped in release)
///   Log.i('message');  // Info
///   Log.w('message');  // Warning
///   Log.e('message');  // Error
class Log {
  static bool get _debug => const bool.fromEnvironment('DEBUG_LOGGING');

  /// Debug-level log — only shown when DEBUG_LOGGING is set or in debug mode.
  static void d(String message) {
    if (_debug) {
      print('🐛 [DEBUG] $message');
    }
  }

  /// Info-level log.
  static void i(String message) {
    print('ℹ️ [INFO] $message');
  }

  /// Warning-level log.
  static void w(String message) {
    print('⚠️ [WARN] $message');
  }

  /// Error-level log with optional exception and stack trace.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    print('❌ [ERROR] $message');
    if (error != null) {
      print('   └─ Exception: $error');
    }
    if (stackTrace != null) {
      print('   └─ StackTrace: $stackTrace');
    }
  }
}
